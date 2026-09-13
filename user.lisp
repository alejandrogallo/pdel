(in-package #:pdel-user)

(defmacro pdel (&rest body)
  `(pdel-pd:launch-form '(progn ,@body)))


(eval-when (:load-toplevel :execute)
  (pdel-lang::load-bundled-library))
