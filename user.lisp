(in-package #:pdel-user)

(defmacro pdel (&rest body)
  `(pdel-pd:launch-form '(progn ,@body)))
