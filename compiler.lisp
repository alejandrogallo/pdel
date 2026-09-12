(in-package #:pdel-compiler)

(defparameter *obj-alist* nil
  "Association list of declared PDEL objects.")

(defparameter *compiler-macro-alist* nil
  "Association list of declared PDEL objects.")

(defparameter *macro-alist* nil
  "Association list of declared PDEL macros.")

(deftype origin ()
  '(member :pdel :foreign :unknown))

(defclass object ()
  ((name :initarg :name :type symbol :reader object-name)
   (origin :initarg :origin :type origin :initform :unknown :reader object-origin)
   (args :initarg :args :initform nil :type list :reader object-args)
   (flags :initarg :flags :initform nil :type list :reader object-flags)
   (inputs :initarg :inputs :initform nil :type list :reader object-inputs)
   (outputs :initarg :outputs :initform nil :type list :reader object-outputs)
   (methods :initarg :methods :initform nil :type list :reader object-methods)
   (source :initarg :source :initform nil :type list :reader object-source)))

(defstruct port
  id
  index)

(defstruct output-values
  "Compiler value holding one source group per declared subpatch outlet."
  values)

(defun declare-object (object)
  "Register OBJECT by name, replacing an older definition of that name."
  (let ((name (object-name object)))
    (setf *obj-alist*
          (acons name object
                 (remove name *obj-alist* :key #'car :test #'eq))))
  object)

(defun find-object (name)
  (cdr (assoc name *obj-alist* :test #'eq)))

(defun find-compiler-macro (name)
  (cdr (assoc name *compiler-macro-alist* :test #'eq)))

(defun split-defpdel-options (forms)
  "Split FORMS into a property list and the remaining source forms."
  (let ((options nil))
    (loop while (and forms (keywordp (first forms)))
          do (let ((key (pop forms)))
               (unless forms
                 (error "Missing value for DEFPDEL option ~S" key))
               (setf (getf options key) (pop forms))))
    (values options forms)))

(defun find-pdel-macro (name)
  (cdr (assoc name *macro-alist* :test #'eq)))

(defclass var ()
    ((name :initarg :name
           :accessor var-name)
     (value :initarg :value
           :accessor var-value)))

(defclass context ()
  ((objects :initarg :objects :initform nil :type list :accessor context-objects)
   (connections :initarg :connections :initform nil :type list
                :accessor context-connections)
   (counter :initarg :counter :initform 0 :type integer :accessor context-counter)
   (bindings :initarg :bindings :initform nil :type list :accessor context-bindings)))


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

(defun context-binding (name ctx)
  (cdr (assoc name (context-bindings ctx) :test #'eq)))

(defun set-binding (name value ctx)
  (let ((entry (assoc name (context-bindings ctx) :test #'eq)))
    (if entry
        (setf (cdr entry) value)
        (push (cons name value)
              (context-bindings ctx)))))

(defun unset-binding (name ctx)
  (let ((entry (assoc name (context-bindings ctx) :test #'eq)))
    (when entry
      (setf (cdr entry) nil))))

(defun push-binding (name value ctx)
  (push (cons name value)
        (context-bindings ctx)))

(defun pop-binding (ctx)
  (pop (context-bindings ctx)))

(defun formal-name (spec)
  "Return the binding name represented by a simple input/output SPEC."
  (etypecase spec
    (symbol spec)
    (cons (first spec))))

(defun formal-type (spec)
  "Return the declared PDEL port type in SPEC, or CONTROL by default."
  (if (and (consp spec) (second spec))
      (second spec)
      'control))

(defun signal-port-p (spec)
  (eq (formal-type spec) 'signal))

(defun context-result (ctx)
  (make-instance
   'pdel-asm:assembly-result
   :elements (sort (copy-list (context-objects ctx))
                   #'< :key #'pdel-asm:asm-element-id)
   :connections (nreverse (context-connections ctx))))

;; todo do it with ports
(defun add-connection (ctx source destination)
  (when source
    (push (pdel-asm:make-connection
           :source (port-id source)
           :source-outlet (port-index source)
           :destination (port-id destination)
           :destination-inlet (port-index destination))
          (context-connections ctx))))

(defun assembly-free-object (form ctx)
  (let* ((name (car form))
         (flags (free-form-flags form))
         (inputs (free-form-inputs form))
         (args (free-form-args form))
         (id (next-element-id ctx))
         (input-connections
           (loop for input in inputs
                 collect (and input (assembly-form input ctx)))))
    (loop for sources in input-connections
          for destination-inlet from 0
          for destination = (make-port :id id
                                       :index destination-inlet)
          do (dolist (source sources)
               (add-connection ctx source destination)))
    (push (make-instance 'pdel-asm:asm-element
                         :name name
                         :type :object
                         :id id
                         :args args
                         :flags flags)
          (context-objects ctx))
    (list (make-port :id id :index 0))))

(defun make-subpatch-assembly (object)
  "Compile OBJECT's stored source into a child assembly.

Declared inputs become child inlet objects and lexical PDEL bindings.  The
source result is connected to the declared outputs; `(outputs ...)' can
supply one independent source group per outlet."
  (let ((ctx (make-instance 'context)))
    ;; Formal inputs are real child inlet objects.  Bind each formal name to
    ;; the normal compiler representation: a list of PORTs.
    (loop for input-spec in (object-inputs object)
          for name = (formal-name input-spec)
          for id = (next-element-id ctx)
          do (push (make-instance 'pdel-asm:asm-element
                                  :name (if (signal-port-p input-spec)
                                            'inlet~
                                            'inlet)
                                  :type :object
                                  :id id)
                   (context-objects ctx))
             (push (cons name
                         (list (make-port :id id :index 0)))
                   (context-bindings ctx)))

    ;; The final source value describes the object outputs.  A normal result
    ;; means output zero.  OUTPUT-VALUES carries one source group per outlet.
    (let ((result nil))
      (dolist (source-form (object-source object))
        (setf result (assembly-form source-form ctx)))

      (when (object-outputs object)
        (let ((groups
                (if (output-values-p result)
                    (output-values-values result)
                    (list result))))
          (unless (= (length groups) (length (object-outputs object)))
            (error "PDEL object ~S declares ~D outputs but its source produced ~D"
                   (object-name object)
                   (length (object-outputs object))
                   (length groups)))

          (loop for output-spec in (object-outputs object)
                for sources in groups
                for outlet-id = (next-element-id ctx)
                do (push (make-instance 'pdel-asm:asm-element
                                        :name (if (signal-port-p output-spec)
                                                  'outlet~
                                                  'outlet)
                                        :type :object
                                        :id outlet-id)
                         (context-objects ctx))
                   (dolist (source sources)
                     (add-connection
                      ctx source (make-port :id outlet-id :index 0)))))))

    (context-result ctx)))

(defun assembly-pdel-object (form object ctx)
  "Compile a call to registered PDEL OBJECT as a nested Pd subpatch."
  (let* ((id (next-element-id ctx))
         (actual-inputs (free-form-inputs form))
         (actual-sources
           (loop for input in actual-inputs
                 collect (and input (assembly-form input ctx))))
         (child (make-subpatch-assembly object)))
    (loop for sources in actual-sources
          for inlet from 0
          for destination = (make-port :id id :index inlet)
          do (dolist (source sources)
               (add-connection ctx source destination)))
    (push (make-instance 'pdel-asm:asm-subpatch
                         :name (object-name object)
                         :type :subpatch
                         :id id
                         :args (free-form-args form)
                         :flags (free-form-flags form)
                         :assembly child)
          (context-objects ctx))
    (list (make-port :id id :index 0))))

(defun assembly-form (form ctx)
  (cond

    ;; variables
    ((symbolp form)
     (or (context-binding form ctx)
         (error "Unbound PDEL symbol ~S" form)))

    ;; compiler macro
    ((and (consp form)
          (find-compiler-macro (car form)))
     (apply (find-compiler-macro (car form))
            ctx (cdr form)))

    ;; pdel macro
    ((and (consp form)
          (find-pdel-macro (car form)))
     (assembly-form
      (apply (find-pdel-macro (car form))
             (cdr form))
      ctx))

    ;; general form
    ((consp form)
     (let* ((name (car form))
            (declared-object (find-object name)))
       (if declared-object
           (assembly-pdel-object form declared-object ctx)
           (assembly-free-object form ctx))))
    (t
     (error "Cannot assemble PDEL form ~S" form))))

(defun assembly (form)
  (let ((ctx (make-instance 'context)))
    (assembly-form form ctx)
    (context-result ctx)))

(defun assembly-pointer-p (value)
  (and (listp value)
       (every #'port-p  value)))

(defun ensure-ids (form ctx)
  (if (assembly-pointer-p form)
      form
      (assembly-form form ctx)))


;; Compiler macros


(defmacro defpdel-macro (name args &body body)
  `(progn
     ;; Register PDEL macro expander.
     (let ((entry (assoc ',name pdel-compiler::*macro-alist* :test #'eq)))
       (if entry
           (setf (cdr entry)
                 (lambda ,args ,@body))
           (push (cons ',name
                       (lambda ,args ,@body))
                 *macro-alist*)))

     ;; Also make it directly executable from Common Lisp.
     (defmacro ,name (&rest call-arguments)
       (list 'pdel-pd:launch-form
             (list 'quote
                   (cons ',name call-arguments))))

     ',name))


(defmacro defpdel (name &rest definition)
  "Define NAME as both a registered PDEL object and a CL launcher macro.

Keyword options currently stored are :ARGS, :INPUTS, :OUTPUTS and :FLAGS.
The remaining forms are the PDEL source of the subpatch.  Calling NAME as a
Common Lisp macro launches that PDEL form through `pdel-pd:launch-form'."
  (multiple-value-bind (options source)
      (split-defpdel-options definition)
    (let ((args (getf options :args))
          (inputs (getf options :inputs))
          (outputs (getf options :outputs))
          (flags (getf options :flags)))
      `(progn
         (eval-when (:compile-toplevel :load-toplevel :execute)
           (declare-object
            (make-instance 'object
                           :name ',name
                           :origin :pdel
                           :args ',args
                           :inputs ',inputs
                           :outputs ',outputs
                           :flags ',flags
                           :source ',source)))
         (defmacro ,name (&rest call-arguments)
           (list 'pdel-pd:launch-form
                 (list 'quote (cons ',name call-arguments))))
         ',name))))

(defmacro defpdel-compiler-macro (name args &body body)
  `(let ((entry (assoc ',name *compiler-macro-alist*)))
     (if entry
         (setf (cdr entry)
               (lambda ,args ,@body))
         (push (cons ',name
                     (lambda ,args ,@body))
               *compiler-macro-alist*))
     ',name))

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
