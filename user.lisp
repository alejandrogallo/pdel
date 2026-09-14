(in-package #:pdel-user)

(defmacro pdel (&rest body)
  `(pdel-pd:launch-form '(progn ,@body)))

(defpdel-macro in (n object)
  `(out ,n ,object))

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

(defpdel dsp-1 ()
  (msg #("; pd dsp 1") (loadbang)))

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
  (do-symbols (sym :pdel-user)
    (export sym :pdel-user))
  pdel-compiler::*obj-alist*)

(eval-when (:load-toplevel :execute)
  (pdel-lang::load-bundled-library))
