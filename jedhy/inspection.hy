"Implements argspec inspection and formatting for various types."

;; * Imports

(import itertools [repeat filterfalse :as remove])

(require jedhy.macros *)
(import jedhy.macros *)

(import inspect
        hy)
(require hyrule *)
(import hyrule *)
(import hyrule [flatten])
(import toolz [juxt drop first second compose])

;; * Parameters

(defclass Parameter []
  (defn __init__ [self symbol [default None]]
    (setv self.symbol (unmangle symbol))
    (setv self.default default))

  (defn __str__ [self]
    (if (is self.default None)
        self.symbol
        (.format "[{} {}]" self.symbol self.default))))

;; * Signature

(defclass Signature []
  (defn __init__ [self func]
    (try (setv argspec (inspect.getfullargspec func))
         (except [e TypeError]
           (raise (TypeError "Unsupported callable for hy Signature."))))

    (setv self.func func)
    (setv [self.args
           self.defaults
           self.kwargs
           self.varargs
           self.varkw]
          ((juxt self.-args-from self.-defaults-from self.-kwargs-from
                 self.-varargs-from self.-varkw-from)
            argspec)))

  (defn [staticmethod] -parametrize [symbols [defaults None]]
    "Construct many Parameter for `symbols` with possibly defaults."
    (when symbols
      (tuple (map Parameter
                  symbols
                  (or defaults (repeat None))))))

  (defn [classmethod] -args-from [cls argspec]
    "Extract args without defined defaults from `argspec`."
    (setv symbols (drop-last (len (or argspec.defaults []))
                             argspec.args))

    (cls.-parametrize symbols))

  (defn [classmethod] -defaults-from [cls argspec]
    "Extract args with defined defaults from `argspec`."
    (setv args-without-defaults (cls.-args-from argspec))
    (setv symbols (drop (len args-without-defaults)
                        argspec.args))

    (cls.-parametrize symbols argspec.defaults))

  (defn [classmethod] -kwargsonly-from [cls argspec]
    "Extract kwargs without defined defaults from `argspec`."
    (setv kwargs-with-defaults (.keys (or argspec.kwonlydefaults {})))
    (setv symbols (remove (f (in kwargs-with-defaults))
                          argspec.kwonlyargs))

    (cls.-parametrize symbols))

  (defn [classmethod] -kwonlydefaults-from [cls argspec]
    "Extract kwargs with defined defaults from `argspec`."
    (when argspec.kwonlydefaults
      (setv [symbols defaults] (zip #* (.items argspec.kwonlydefaults)))

      (cls.-parametrize symbols defaults)))

  (defn [classmethod] -kwargs-from [cls argspec]
    "Chain kwargs with and without defaults, since `argspec` doesn't order."
    (->> argspec
         ((juxt cls.-kwargsonly-from cls.-kwonlydefaults-from))
         flatten
         (remove (fn [it] (is it None)))
         tuple))

  (defn [staticmethod] -varargs-from [argspec]
    (and argspec.varargs [(unmangle argspec.varargs)]))

  (defn [staticmethod] -varkw-from [argspec]
    (and argspec.varkw [(unmangle argspec.varkw)]))

  (defn [staticmethod] -format-args [args opener]
    (unless args
      (return ""))

    (setv args (map str args))
    (setv opener (if opener (+ opener " ") (str)))

    (+ opener (.join " " args)))

  (defn [classmethod] -acc-lispy-repr [cls acc args-opener]
    (setv [args opener] args-opener)
    (setv delim (if (and acc args) " " (str)))

    (+ acc delim (cls.-format-args args opener)))

  (defn [property] -arg-opener-pairs [self]
    [[self.args     None]
     [self.defaults "&optional"]
     [self.varargs  "#*"]
     [self.varkw    "#**"]
     [self.kwargs   "*"]])

  (defn __str__ [self]
    (reduce self.-acc-lispy-repr self.-arg-opener-pairs (str))))

;; * Docstring conversion

(defn -split-docs [docs]
  "Partition docs string into pre/-/post-args strings."
  (setv arg-start (inc (.index docs "(")))
  (setv arg-end (.index docs ")"))

  [(cut docs 0 arg-start)
   (cut docs arg-start arg-end)
   (cut docs arg-end)])

(defn -argstring-to-param [arg-string]
  "Convert an arg string to a Parameter."
  (unless (in "=" arg-string)
    (return (Parameter arg-string)))

  (setv [arg-name - default] (.partition arg-string "="))

  (if (= "None" default)
      (Parameter arg-name)
      (Parameter arg-name default)))

(defn -optional-arg-idx [args-strings]
  "First idx of an arg with a default in list of args strings."
  (defn -at-arg-with-default? [idx-arg]
    (when (in "=" (second idx-arg)) (first idx-arg)))

  (->> args-strings
       enumerate
       (map -at-arg-with-default?)
       (remove (fn [it] (is it None)))  ; Can't use `some` since idx could be zero
       first))

(defn -insert-optional [args]
  "Insert &optional into list of args strings."
  (setv optional-idx (-optional-arg-idx args))

  (unless (is optional-idx None)
    (.insert args optional-idx "&optional"))

  args)

(defn builtin-docs-to-lispy-docs [docs]
  "Convert built-in-styled docs string into a lispy-format."
  ;; Check if docs is non-standard
  (unless (and (in "(" docs)
               (in ")" docs))
    (return docs))

  (setv replacements [["..." "#* args"]
                      ["*args" "#* args"]
                      ["**kwargs" "#** kwargs"]
                      ["\n" "newline"]
                      ["-->" "- return"]])

  (setv [pre-args - post-args] (.partition docs "("))

  ;; Format before args and perform unconditional conversions
  (setv [pre-args args post-args]
        (->> post-args
             (.format "{}: ({}" pre-args)
             (reduce (fn [s old-new]
                       (.replace s (first old-new) (second old-new)))
                     replacements)
             -split-docs))

  ;; Format and reorder args and reconstruct the string
  (+ pre-args
     (as-> args args
           (.split args ",")
           (map str.strip args)
           (list args)
           (-insert-optional args)
           (map (compose str -argstring-to-param) args)
           (.join " " args))
     post-args))

;; * Inspect
;; ** Internal

(defclass Inspect []
  (defn __init__ [self obj]
    (setv self.obj obj))

  (defn [property] -docs-first-line [self]
    (or (and self.obj.__doc__
             (-> self.obj.__doc__ (.splitlines) first))
        ""))

  (defn [property] -docs-rest-lines [self]
    (or (and self.obj.__doc__
             (->> self.obj.__doc__ (.splitlines) rest (.join "\n")))
        ""))

  (defn [property] -args-docs-delim [self]
    (or (and self.obj.__doc__
             " - ")
        ""))

  (defn -cut-obj-name-maybe [self docs]
    (if (or self.class?
            self.method-wrapper?)
        (-> docs
            (.replace "self " "")
            (.replace "self" ""))
        docs))

  (defn -cut-method-wrapper-maybe [self docs]
    (if self.method-wrapper?
        (+ "method-wrapper"
           (cut docs (.index docs ":")))
        docs))

  (defn -format-docs [self docs]
    (-> docs
        (self.-cut-obj-name-maybe)
        (self.-cut-method-wrapper-maybe)))

  ;; ** Properties

  (defn [property] obj-name [self]
    (unmangle self.obj.__name__))

  (defn [property] lambda? [self]
    "Is object a lambda?"
    (= self.obj-name "<lambda>"))

  (defn [property] class? [self]
    "Is object a class?"
    (inspect.isclass self.obj))

  (defn [property] method-wrapper? [self]
    "Is object of type 'method-wrapper'?"
    (isinstance self.obj (type print.__str__)))

  (defn [property] compile-table? [self]
    "Is object a Hy compile table construct?"
    (= self.-docs-first-line
       "Built-in immutable sequence."))

  ;; ** Actions

  (defn signature [self]
    "Return object's signature if it exists."
    (try (Signature self.obj)
         (except [e TypeError] None)))

  (defn docs [self]
    "Formatted first line docs for object."
    (setv signature (self.signature))

    (self.-format-docs
      (cond
        (and signature (not self.compile-table?))
        (.format "{name}: ({args}){delim}{docs}"
                 :name self.obj-name
                 :args signature
                 :delim self.-args-docs-delim
                 :docs self.-docs-first-line)
        self.compile-table? "Compile table"
        True (builtin-docs-to-lispy-docs self.-docs-first-line))))

  (defn full-docs [self]
    "Formatted full docs for object."
    ;; TODO There are builtins to format the -docs-rest-lines part I should use
    (unless self.compile-table?
      (if self.-docs-rest-lines
          (.format "{}\n\n{}"
                   (self.docs)
                   self.-docs-rest-lines)
          (self.docs)))))
