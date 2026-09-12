(in-package #:pdel-asm)

(defclass asm-element ()
  ((id
    :initarg :id
    :type integer
    :reader asm-element-id)
   (name
    :initarg :name
    :type string
    :reader asm-element-name)
   (type
    :initarg :type
    :reader asm-element-type)
   (args
    :initarg :args
    :initform nil
    :type list
    :reader asm-element-args)
   (flags
    :initarg :flags
    :initform nil
    :type list
    :reader asm-element-flags)
   (inputs
    :initarg :inputs
    :initform nil
    :type list
    :reader asm-element-inputs)
   (outputs
    :initarg :outputs
    :initform nil
    :type list
    :reader asm-element-outputs)

   (x
    :initarg :x
    :initform 0
    :reader asm-element-x
    :type real)
   (y
    :initarg :y
    :initform 0
    :reader asm-element-y
    :type real)
   (width
    :initarg :width
    :initform 100
    :reader asm-element-width
    :type real)
   (height
    :initarg :height
    :initform 10
    :reader asm-element-height
    :type real)
   ;; Graphviz's original center coordinates are sometimes useful.
   (center-x
    :initarg :center-x
    :initform 0
    :reader asm-element-center-x
    :type real)

   (center-y
    :initarg :center-y
    :initform 0
    :reader asm-element-center-y
    :type real)))


