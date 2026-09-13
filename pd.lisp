(in-package #:pdel-pd)

(defun escape-pd-text (value)
  "Escape VALUE for use as one or more atoms in a .pd patch file."
  (let ((text (princ-to-string value)))
    (when (or (find #\Newline text) (find #\Return text))
      (error "Pure Data atoms cannot contain newlines: ~S" value))
    ;; Match the escaping policy of the old Emacs Lisp backend.
    (with-output-to-string (out)
      (loop for ch across (princ-to-string value)
            do (case ch
                 (#\, (write-string " \\, " out))
                 (#\; (write-string "\\;" out))
                 (#\$ (write-string "\\$" out))
                 (t (write-char ch out)))))))

(defun pd-token (value)
  (etypecase value
    (symbol (escape-pd-text (string-downcase (symbol-name value))))
    (string (escape-pd-text value))
    (number (princ-to-string value))))

(defun write-pd-arguments (arguments stream)
  (loop for arg in arguments
        for first = t then nil
        do (unless first (write-char #\Space stream))
           (write-string (pd-token arg) stream)))

(defun write-pd-element (element stream)
  (let ((x (round (pdel-asm:asm-element-x element)))
        (y (round (pdel-asm:asm-element-y element)))
        (name (pdel-asm:asm-element-name element))
        (type (pdel-asm:asm-element-type element))
        (args (pdel-asm:asm-element-args element)))
    (case type
      (:object
       (format stream "#X obj ~d ~d ~a" x y (pd-token name))
       (when args
         (write-char #\Space stream)
         (write-pd-arguments args stream))
       (write-string ";" stream))
      (:message
       (format stream "#X msg ~d ~d " x y)
       (write-pd-arguments args stream)
       (write-string ";" stream))
      (:text
       (format stream "#X text ~d ~d " x y)
       (write-pd-arguments args stream)
       (write-string ";" stream))
      (:floatatom
       (format stream "#X floatatom ~d ~d" x y)
       (when args (write-char #\Space stream) (write-pd-arguments args stream))
       (write-string ";" stream))
      (:symbolatom
       (format stream "#X symbolatom ~d ~d" x y)
       (when args (write-char #\Space stream) (write-pd-arguments args stream))
       (write-string ";" stream))
      (:listbox
       (format stream "#X listbox ~d ~d" x y)
       (when args (write-char #\Space stream) (write-pd-arguments args stream))
       (write-string ";" stream))
      (:raw-element
       ;; Unknown connectable #X records parsed by the disassembler retain
       ;; their complete textual record in the first argument.
       (write-string (or (first args) "") stream)
       (unless (and args
                    (> (length (first args)) 0)
                    (char= (char (first args) (1- (length (first args)))) #\;))
         (write-char #\; stream)))
      (otherwise
       (error "Unsupported assembly element type ~S for ~S" type element)))
    (terpri stream)))

(defun write-pd-connection (connection stream)
  (format stream "#X connect ~d ~d ~d ~d;~%"
          (pdel-asm:connection-source connection)
          (pdel-asm:connection-source-outlet connection)
          (pdel-asm:connection-destination connection)
          (pdel-asm:connection-destination-inlet connection)))

(defun write-pd-assembly-body (assembly stream)
  "Write ASSEMBLY records inside an already-open Pd canvas."
  (dolist (arguments (pdel-asm:assembly-declarations assembly))
    (write-string "#X declare" stream)
    (when arguments
      (write-char #\Space stream)
      (write-pd-arguments arguments stream))
    (write-string ";" stream)
    (terpri stream))
  (dolist (element (pdel-asm:assembly-elements assembly))
    (if (typep element 'pdel-asm:asm-subpatch)
        (let ((child (pdel-asm:asm-subpatch-assembly element)))
          (format stream "#N canvas 0 0 ~d ~d ~a 0;~%"
                  (max 1 (ceiling (pdel-asm:assembly-width child)))
                  (max 1 (ceiling (pdel-asm:assembly-height child)))
                  (pd-token (pdel-asm:asm-element-name element)))
          (write-pd-assembly-body child stream)
          (format stream "#X restore ~d ~d pd ~a;~%"
                  (round (pdel-asm:asm-element-x element))
                  (round (pdel-asm:asm-element-y element))
                  (pd-token (pdel-asm:asm-element-name element))))
        (write-pd-element element stream)))
  (dolist (connection (pdel-asm:assembly-connections assembly))
    (write-pd-connection connection stream))
  ;; RAW is intentionally structural: it does not consume a Pd object index.
  ;; Emit it after ordinary graph records, which is useful for records such as
  ;; #X coords.  Use a real assembly element for anything connectable.
  (dolist (record (pdel-asm:assembly-raw-records assembly))
    (write-string record stream)
    (unless (and (> (length record) 0)
                 (char= (char record (1- (length record))) #\Newline))
      (terpri stream))))

(defun write-pd (assembly pathname)
  (ensure-directories-exist pathname)
  (with-open-file (stream pathname
                          :direction :output
                          :if-exists :supersede
                          :if-does-not-exist :create)
    (format stream "#N canvas 0 0 ~d ~d 10;~%"
            (max 1 (ceiling (pdel-asm:assembly-width assembly)))
            (max 1 (ceiling (pdel-asm:assembly-height assembly))))
    (write-pd-assembly-body assembly stream))
  pathname)

(defun pdel->pd (forms pathname)
  (let ((asm (pdel-compiler:assembly forms)))
    (write-pd asm pathname)))

(defun temporary-pd-pathname ()
  "Return a fresh temporary pathname suitable for a generated Pd patch."
  (merge-pathnames
   (make-pathname
    :name (format nil "pdel-~36r" (random most-positive-fixnum))
    :type "pd")
   (uiop:temporary-directory)))

(defun launch-form (form &key
                           (pd "pd")
                           (gui t)
                           pathname
                           (arguments nil))
  "Compile FORM, lay it out, write a .pd file, and launch Pure Data."
  (let* ((assembly (pdel-compiler:assembly form))
         (output (or pathname (temporary-pd-pathname))))
    (pdel-layout:layout assembly)
    (write-pd assembly output)
    (let ((process
            (uiop:launch-program
             (append (list pd)
                     (unless gui (list "-nogui"))
                     arguments
                     (list (namestring output)))
             :output :interactive
             :error-output :interactive
             :wait nil)))
      (values process output assembly))))
