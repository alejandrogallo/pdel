(in-package #:pdel-lang)


(defpdel-compiler-macro outputs (ctx &rest forms)
  "Return one independently routable source group for each FORM."
  (make-output-values
   :values (mapcar (lambda (form)
                     (ensure-ids form ctx))
                   forms)))

(defpdel-compiler-macro join (ctx &rest objects)
  (loop for o in objects
        append (copy-list (ensure-ids o ctx))))

(defpdel-compiler-macro defvar (ctx var-name object)
  (set-binding var-name (ensure-ids object ctx) ctx))

(defpdel-compiler-macro undefvar (ctx var-name)
  (unset-binding var-name ctx))

(defpdel-compiler-macro progn (ctx &rest body)
  (loop for form in body
        for result = (assembly-form form ctx)
        finally (return result)))

(defpdel-compiler-macro let (ctx bindings &rest body)
  ;; LET semantics: compile all initializers before introducing bindings.
  (let ((values
         (loop for (name form) in bindings
               collect
               (cons name
                     (ensure-ids form ctx)))))

    (unwind-protect
         (progn
           (dolist (binding values)
             (push binding
                   (context-bindings ctx)))

           (assembly-form
            (cons 'progn body)
            ctx))

      ;; Remove exactly the bindings introduced above.
      (dotimes (_ (length values))
        (pop (context-bindings ctx))))))

(defpdel-compiler-macro let* (ctx bindings &rest body)
  (if bindings
      (assembly-form
       `(let (,(car bindings))
          (let* ,(cdr bindings)
            ,@body))
       ctx)
    (assembly-form
     `(progn ,@body)
     ctx)))

(defpdel-compiler-macro out (ctx n object)
  (let* ((ids (ensure-ids object ctx))
         (id (car ids)))
    (when (> (length ids) 1)
      (error "It does not make sound to calculate the out of many objects"))
    (list (make-port :id (port-id id)
                     :index n))))

(defpdel-macro in (n object)
  `(out ,n ,object))

(defpdel-compiler-macro -> (ctx &rest objects)
  (let* ((ids (mapcar (lambda (o)
                        (ensure-ids o ctx))
                      objects))
         (first (car ids)))
    (dolist (out (cdr ids) first)
      (dolist (f first)
        (dolist (o out)
          (add-connection ctx f o)))
      (setf first out))))

(defpdel-macro multiple-outlet-bind (names object &rest body)
  (let ((tmp (gensym "OBJECT")))
    `(let ((,tmp ,object))
       (let ,(loop for name in names
                   for outlet from 0
                   collect `(,name (out ,outlet ,tmp)))
         ,@body))))

(defpdel-macro chain (&rest forms)
  (reduce
   (lambda (input form)
     (append form (list input)))
   (cdr forms)
   :initial-value (car forms)))

(defpdel-macro fanout (source &rest destinations)
  (let ((tmp (gensym "SOURCE")))
    `(let ((,tmp ,source))
       ,@(mapcar
          (lambda (destination)
            `(-> ,tmp ,destination))
          destinations)
       ,tmp)))


(defun load-bundled-library (&optional
                               (root (merge-pathnames
                                      #P"lib/"
                                      (asdf:system-source-directory :pdel))))
  "Load every bundled DEFPDEL definition below ROOT.

The files retain the .pdel extension but now contain ordinary Common Lisp
DEFPDEL forms."
  (labels ((walk (directory)
             (dolist (file (sort (copy-list (directory (merge-pathnames #P"*.pdel" directory)))
                                 #'string< :key #'namestring))
               (load file))
             (dolist (subdir (sort (copy-list (uiop:subdirectories directory))
                                   #'string< :key #'namestring))
               (walk subdir))))
    (walk root))
  *obj-alist*)

(eval-when (:load-toplevel :execute)
  (load-bundled-library))
