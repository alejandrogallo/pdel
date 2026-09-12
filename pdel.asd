(asdf:defsystem #:pdel
  :description "Common Lisp compiler for Pure Data patches"
  :version "0.2.1"
  :author "Alejandro Gallo; Common Lisp port"
  :license "GPL-3.0-or-later"
  :serial t
  :depends-on (#:s-graphviz #:alexandria #:uiop)
  :components ((:file "package")
               (:file "asm")
               (:file "layout")
               (:file "pd")
               (:file "lang")
               (:file "lib")))

(asdf:defsystem #:pdel/tests
  :depends-on (#:pdel)
  :serial t
  :components ((:file "tests/tests"))
  :perform (asdf:test-op (op system)
             (declare (ignore op system))
             (uiop:symbol-call :pdel/tests :run-tests)))

