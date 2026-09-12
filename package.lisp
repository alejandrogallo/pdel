(defpackage #:pdel-asm
  (:use #:cl)
  (:export
   #:asm-element #:asm-element-id #:asm-element-name #:asm-element-type
   #:asm-element-args #:asm-element-flags #:asm-element-inputs #:asm-element-outputs
   #:asm-element-x #:asm-element-y #:asm-element-width #:asm-element-height
   #:asm-element-center-x #:asm-element-center-y
   #:connection #:make-connection
   #:connection-source #:connection-source-outlet
   #:connection-destination #:connection-destination-inlet
   #:assembly-result #:assembly-elements #:assembly-connections
   #:assembly-width #:assembly-height #:find-element-by-id))


(defpackage #:pdel-lang
  (:use #:cl)
  (:export
   #:object #:object-origin #:object-args #:object-flags
   #:object-inputs #:object-outputs #:object-methods #:object-source
   #:declare-object #:find-object
   #:free-form-flags #:free-form-args #:free-form-inputs
   #:assembly))


(defpackage #:pdel-layout
  (:use #:cl)
  (:export
   #:*graphviz-dpi*
   #:assembly->graphviz
   #:write-dot-file
   #:layout
   #:layout-with-dot-file))


(defpackage #:pdel-graphviz
  (:use #:cl)
  (:export
   #:parse-result->graphviz
   #:write-dot-file
   #:graphviz-layout
   #:layout-element
   #:layout-element-id
   #:layout-element-x
   #:layout-element-y
   #:layout-element-width
   #:layout-element-height
   #:layout-result
   #:layout-result-width
   #:layout-result-height
   #:layout-result-elements))


(defpackage #:pdel-pd
  (:use #:cl)
  (:export #:write-pd #:write-pd-element #:write-pd-connection))
