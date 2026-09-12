(in-package #:pdel-lang)


(defparameter *obj-alist* nil
  "Association list of declared PDEL objects.")

(defun declare-object (object)
  (let ((name (pdel-asm:asm-element-name object)))
    (setf *obj-alist*
          (acons name object
                 (remove name *obj-alist* :key #'car :test #'eq))))
  object)

(defun find-object (name)
  (cdr (assoc name *obj-alist* :test #'eq)))

(deftype origin ()
  '(member :pdel :foreign :unknown))

(defclass object ()
  ((origin :initarg :origin :type origin :initform :unknown :reader object-origin)
   (args :initarg :args :initform nil :type list :reader object-args)
   (flags :initarg :flags :initform nil :type list :reader object-flags)
   (inputs :initarg :inputs :initform nil :type list :reader object-inputs)
   (outputs :initarg :outputs :initform nil :type list :reader object-outputs)
   (methods :initarg :methods :initform nil :type list :reader object-methods)
   (source :initarg :source :initform nil :reader object-source)))

(defclass context ()
  ((objects :initarg :objects :initform nil :type list :accessor context-objects)
   (connections :initarg :connections :initform nil :type list
                :accessor context-connections)
   (counter :initarg :counter :initform 0 :type integer :accessor context-counter)))

(defun free-form-flags (form)
  (loop for tail on form
        when (keywordp (car tail))
          return tail))

(defun free-form-args (form)
  (let ((args (second form)))
    (when (vectorp args)
      (coerce args 'list))))

(defun free-form-inputs (form)
  (let (inputs)
    (loop for f in (cdr form)
          if (keywordp f)
            return nil
          if (not (vectorp f))
            do (push f inputs))
    (nreverse inputs)))

(defun next-element-id (ctx)
  (prog1 (context-counter ctx)
    (incf (context-counter ctx))))

(defun assembly-form (form ctx)
  (let* ((name (car form))
         (declared-object (find-object name)))
    (if declared-object
        (error "Declared-object compilation is not implemented yet for ~S" name)
        (let* ((flags (free-form-flags form))
               (inputs (free-form-inputs form))
               (args (free-form-args form))
               (id (next-element-id ctx))
               (input-connections
                 (loop for input in inputs
                       collect (assembly-form input ctx))))
          (loop for (source-id . source-outlet) in input-connections
                for destination-inlet from 0
                do
                   (push
                    (pdel-asm:make-connection
                     :source source-id
                     :source-outlet source-outlet
                     :destination id
                     :destination-inlet destination-inlet)
                    (context-connections ctx)))
          (push (make-instance 'pdel-asm:asm-element
                               :name name
                               :type :object
                               :id id
                               :args args
                               :flags flags)
                (context-objects ctx))
          (cons id 0)))))

(defun assembly (form)
  (let ((ctx (make-instance 'context)))
    (assembly-form form ctx)
    (make-instance
     'pdel-asm:assembly-result
     :elements
     (sort (copy-list (context-objects ctx))
           #'< :key #'pdel-asm:asm-element-id)
     :connections
     (nreverse (context-connections ctx)))))
