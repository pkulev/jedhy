(require hyrule [->>])
(import pytest)


;; * Asserts

(defn assert= [x y]
  (assert (= x y)))

(defn assert-in [x y]
  (assert (in x y)))

(defn assert-not-in [x y]
  (assert (not-in x y)))

(defn assert-all-in [x y]
  (assert (->> x (map (fn [z] (in z y))) all)))

;; * Pytest Fixtures

(defmacro deffixture [fn-name docstring params #* body]
  "Pytest parametrize reader."

  `(defn [(pytest.fixture :params ~params :scope "module")] ~fn-name [request]
     ~docstring
     (setv it request.param)
     ~@body))

(defmacro with-fixture [fixture fn-name args #* body]
  `(defn ~fn-name [~fixture]
     (setv ~args ~fixture)
     ~@body))

(defmacro assert-raises [error #* code]
  `(with [(pytest.raises ~error)] ~@code))
