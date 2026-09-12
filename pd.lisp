(in-package #:pdel-pd)

(defun pd-token (value)
  (etypecase value
    (symbol (string-downcase (symbol-name value)))
    (string value)
    (number (princ-to-string value))))

(defun write-pd-element (element stream)
  (format stream "#X obj ~d ~d ~a"
          (round (pdel-asm:asm-element-x element))
          (round (pdel-asm:asm-element-y element))
          (pd-token (pdel-asm:asm-element-name element)))
  (dolist (arg (pdel-asm:asm-element-args element))
    (format stream " ~a" (pd-token arg)))
  (write-string ";" stream)
  (terpri stream))

(defun write-pd-connection (connection stream)
  (format stream "#X connect ~d ~d ~d ~d;~%"
          (pdel-asm:connection-source connection)
          (pdel-asm:connection-source-outlet connection)
          (pdel-asm:connection-destination connection)
          (pdel-asm:connection-destination-inlet connection)))

(defun write-pd (assembly pathname)
  (ensure-directories-exist pathname)
  (with-open-file (stream pathname
                          :direction :output
                          :if-exists :supersede
                          :if-does-not-exist :create)
    (format stream "#N canvas 0 0 ~d ~d 10;~%"
            (max 1 (ceiling (pdel-asm:assembly-width assembly)))
            (max 1 (ceiling (pdel-asm:assembly-height assembly))))
    (dolist (element (pdel-asm:assembly-elements assembly))
      (write-pd-element element stream))
    (dolist (connection (pdel-asm:assembly-connections assembly))
      (write-pd-connection connection stream)))
  pathname)
