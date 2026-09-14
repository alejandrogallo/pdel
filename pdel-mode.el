
(define-derived-mode pdel-mode lisp-mode "PDEL"
                     "Major mode for Pure Data S-expressions.")

(add-to-list 'auto-mode-alist '("\\.pdel\\'" . pdel-mode))

(provide 'pdel-mode)
