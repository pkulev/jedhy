"Some general purpose imports and code."

;; * Imports

(require hyrule *)
(import hyrule *)

(import itertools [starmap]
        functools
        toolz [last]
        toolz.curried :as tz
        hy [unmangle
            mangle :as unfixed-mangle])

;; * Hy Overwrites

;; We have different requirements in the empty string case
(defn mangle [s]
  (if (!= s "") (unfixed-mangle s) (str)))

;; * Tag Macros

(defmacro t [form]
  "Cast evaluated form to a tuple. Useful via eg. #t(-> x f1 f2 ...)."
  `(tuple ~form))

(defmacro f [form]
  "Flipped #$."
  `(tz.flip ~@form))

;; * Misc

(defn -allkeys [d * [parents #()]]
  "In-order tuples of keys of nested, variable-length dict."
  (if (isinstance d #(list tuple))
      []
      (t (->> d
              (tz.keymap (fn [k] (+ parents #(k))))
              (dict.items)
              (starmap (fn [k v]
                         (if (isinstance v dict)
                             (-allkeys v :parents k)
                             [k])))
              (tz.concat)))))

(defn allkeys [d]
  (->> d -allkeys (map last) tuple))
