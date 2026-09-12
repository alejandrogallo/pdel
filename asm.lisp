(in-package #:pdel-asm)



(defclass asm-element ()
  ((id :initarg :id :type integer :reader asm-element-id)
   (name :initarg :name :type symbol :reader asm-element-name)
   (type :initarg :type :reader asm-element-type)
   (args :initarg :args :initform nil :type list :reader asm-element-args)
   (flags :initarg :flags :initform nil :type list :reader asm-element-flags)
   (inputs :initarg :inputs :initform nil :type list :reader asm-element-inputs)
   (outputs :initarg :outputs :initform nil :type list :reader asm-element-outputs)

   ;; Filled by the layout pass.
   (x :initarg :x :initform 0 :type real :accessor asm-element-x)
   (y :initarg :y :initform 0 :type real :accessor asm-element-y)
   (width :initarg :width :initform 100 :type real :accessor asm-element-width)
   (height :initarg :height :initform 20 :type real :accessor asm-element-height)
   (center-x :initarg :center-x :initform 0 :type real
             :accessor asm-element-center-x)
   (center-y :initarg :center-y :initform 0 :type real
             :accessor asm-element-center-y)))

(defstruct connection
  (source 0 :type integer)
  (source-outlet 0 :type integer)
  (destination 0 :type integer)
  (destination-inlet 0 :type integer))

(defclass assembly-result ()
  ((elements :initarg :elements :initform nil :type list :reader assembly-elements)
   (connections :initarg :connections :initform nil :type list
                :reader assembly-connections)
   (width :initarg :width :initform 0 :type real :accessor assembly-width)
   (height :initarg :height :initform 0 :type real :accessor assembly-height)))

(defun find-element-by-id (assembly id)
  (find id (assembly-elements assembly)
        :key #'asm-element-id :test #'=))
