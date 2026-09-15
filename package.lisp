(defpackage #:pdel-asm
  (:use #:cl)
  (:export
   #:asm-element #:asm-element-id #:asm-element-name #:asm-element-type
   #:asm-element-args #:asm-element-flags #:asm-element-inputs #:asm-element-outputs
   #:asm-element-x #:asm-element-y #:asm-element-width #:asm-element-height
   #:asm-element-center-x #:asm-element-center-y
   #:asm-subpatch #:asm-subpatch-assembly
   #:connection #:make-connection
   #:connection-source #:connection-source-outlet
   #:connection-destination #:connection-destination-inlet
   #:assembly-result #:assembly-elements #:assembly-connections
   #:assembly-declarations #:assembly-raw-records
   #:assembly-width #:assembly-height #:find-element-by-id))

(defpackage #:pdel-compiler
  (:use #:cl)
  (:export
   #:object #:object-name #:object-origin #:object-args #:object-flags
   #:object-inputs #:object-outputs #:object-methods #:object-source
   #:declare-object #:find-object #:find-pdel-macro #:find-compiler-macro #:pdel-name=
   #:defpdel
   #:defpdel-macro
   #:free-form-flags #:free-form-args #:free-form-inputs
   #:assembly))

(defpackage #:pdel-lang
  (:use #:cl)
  (:import-from #:pdel-compiler
                #:defpdel
                #:defpdel-macro)
  (:export
   ))

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
  (:export
   #:write-pd
   #:write-pd-element
   #:write-pd-connection
   #:launch-form
   #:pdel->pd))


(defpackage #:pdel-disassembler
  (:use #:cl)
  (:export
   #:disassembly #:disassembly-definitions #:disassembly-form
   #:read-pd-string #:read-pd-file
   #:disassemble-assembly #:disassemble-pd-string #:disassemble-pd-file
   #:disassembly-to-string #:write-disassembly))

(defpackage #:pdel-user
  (:use #:cl #:pdel-lang)
  (:import-from #:pdel-compiler
                #:defpdel
                #:defpdel-macro)
  (:export
   #:write-pd
   #:write-pd-element
   #:write-pd-connection
   #:launch-form
   #:defpdel-macro
   #:defpdel
   #:load-bundled-library
   #:pdel
   #:knob!
   #:bng!
   #:slider-h
   #:slider-v
   #:switch-toggle
   #:radio-h
   #:switch-radio-v
   #:box-new))


(defpackage #:pdel
  (:use #:cl)
  (:import-from #:pdel-compiler
                #:defpdel
                #:defpdel-macro)
  (:import-from #:pdel-user
                #:pdel)
  (:export
   #:launch-form
   #:defpdel
   #:defpdel-macro
   #:pdel))
