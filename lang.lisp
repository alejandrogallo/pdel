(in-package #:pdel-lang)

(defparameter *obj-alist* nil
  "Objlist for all defined elements.")


(defun declare-object (object)
  (push (cons (pdel-parse:asm-element-name object)
              object)
        *obj-alist*))

(defun find-object (name)
  (cdr (assoc name *obj-alist*)))

(deftype origin ()
  '(member :pdel :foreign :unknown))


(defclass object ()
  ((origin
    :initarg :origin
    :type origin
    :initform :unknown
    :reader object-origin)
   (args
    :initarg :args
    :type list
    :reader object-args)
   (flags
    :initarg :flags
    :type list
    :reader object-flags)
   (inputs
    :initarg :inputs
    :type list
    :reader object-inputs)
   (outputs
    :initarg :outputs
    :type list
    :reader object-outputs)
   (methods
    :initarg :methods
    :reader object-methods)
   (source :initarg :source
           :reader object-source)))


(defclass context ()
  ((objects
    :initarg :objects
    :initform nil
    :type list
    :accessor context-objects)
   (connections
    :initarg :connections
    :type list
    :accessor context-connections
    :initform nil)
   (counter
    :initarg :counter
    :accessor context-counter
    :type integer
    :initform 0)))

(defun free-form-flags (form)
  (loop for f in form
        for i from 0
        when (keywordp f)
          return (subseq form i)))

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

(free-form-inputs '(osc~ #(5 6 8)
                    (mtofreq (midiin))
                    (adc~)
                    :half t))

(free-form-args '(osc~ #(5 6 8) (mtofreq (midiin))
                  :half t))

(free-form-flags '(osc~ (5 6 8) (mtofreq (midiin))
                   :half t))


(defclass parse-result ()
  ((elements
    :initarg :elements
    :type list
    :reader parse-result-elements)
   (connections
    :initarg :connections
    :type list
    :reader parse-result-connections)))


(defun assembly-form (form ctx)
  (let* ((name (car form))
         (object (find-object name)))
    (if object
        (error "TODO")
        ;; free form
        (let* ((flags (free-form-flags form))
              (inputs (free-form-inputs form))
              (args (free-form-args form))
              (id (prog1 (context-counter ctx)
                    (incf (context-counter ctx))))
              (input-connections
                (loop for i in inputs
                      collect (assembly-form i ctx))))
          (loop for conn in input-connections
                for i from 0
                do
                (push (cons conn (cons id i))
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
     'parse-result
     :elements (sort (context-objects ctx)
                     #'<
                     :key #'pdel-asm:asm-element-id)
     :connections (context-connections ctx))))

