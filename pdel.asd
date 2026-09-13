(asdf:defsystem #:pdel
  :description "Common Lisp compiler for Pure Data patches"
  :version "0.2.1"
  :author "Alejandro Gallo; Common Lisp port"
  :license "GPL-3.0-or-later"
  :serial t
  :depends-on (#:s-graphviz #:alexandria #:uiop)
  :in-order-to ((test-op (test-op "pdel/tests")))
  :components ((:file "package")
               (:file "asm")
               (:file "layout")
               (:file "pd")
               (:file "compiler")
               (:file "lib")
               (:file "disassembler")
               (:file "user")))

(asdf:defsystem #:pdel/tests
  :depends-on (#:pdel #:fiveam)
  :serial t
  :components ((:file "tests/tests"))
  :perform (asdf:test-op (op system)
             (declare (ignore op system))
             (uiop:symbol-call :pdel/tests :run-tests)))

