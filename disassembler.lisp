(in-package #:pdel-disassembler)

;;;; Results -----------------------------------------------------------------

(defstruct disassembly
  "A decompiled PDEL unit.
DEFINITIONS contains DEFPDEL forms needed by nested subpatches.  FORM is the
main PDEL graph form."
  definitions
  form)

(defun pdel-symbol (name)
  "Intern NAME in PDEL-LANG for readable generated PDEL source."
  (intern (string-upcase name) (find-package :pdel-lang)))

(defun local-symbol (format-control &rest args)
  "Create a readable generated symbol in PDEL-LANG."
  (pdel-symbol (apply #'format nil format-control args)))

;;;; Pure Data text reader ----------------------------------------------------

(defun pd-statements (text)
  "Split Pd TEXT into semicolon-terminated records.
Escaped semicolons remain part of their record.  Returned strings omit the
terminating semicolon and surrounding whitespace."
  (let ((records nil)
        (start 0)
        (escaped nil))
    (loop for i from 0 below (length text)
          for ch = (char text i)
          do (cond
               (escaped (setf escaped nil))
               ((char= ch #\\) (setf escaped t))
               ((char= ch #\;)
                (let ((record (string-trim '(#\Space #\Tab #\Newline #\Return)
                                           (subseq text start i))))
                  (unless (string= record "")
                    (push record records)))
                (setf start (1+ i)))))
    (let ((tail (string-trim '(#\Space #\Tab #\Newline #\Return)
                             (subseq text start))))
      (unless (string= tail "")
        (push tail records)))
    (nreverse records)))

(defun pd-words (record)
  "Tokenize one Pd RECORD, undoing backslash escapes.
This is intentionally a textual Pd tokenizer, not a Lisp reader."
  (let ((words nil)
        (buffer (make-string-output-stream))
        (escaped nil)
        (have-char nil))
    (labels ((finish ()
               (when have-char
                 (push (get-output-stream-string buffer) words)
                 (setf buffer (make-string-output-stream)
                       have-char nil))))
      (loop for ch across record
            do (cond
                 (escaped
                  (write-char ch buffer)
                  (setf have-char t escaped nil))
                 ((char= ch #\\)
                  (setf escaped t))
                 ((member ch '(#\Space #\Tab #\Newline #\Return))
                  (finish))
                 (t
                  (write-char ch buffer)
                  (setf have-char t))))
      ;; Preserve a terminal backslash literally rather than dropping data.
      (when escaped
        (write-char #\\ buffer)
        (setf have-char t))
      (finish)
      (nreverse words))))

(defun maybe-number (string)
  "Return STRING parsed as a number when it is entirely numeric."
  (let ((*read-eval* nil))
    (handler-case
        (multiple-value-bind (value end)
            (read-from-string string nil nil)
          (if (and value
                   (= end (length string))
                   (numberp value))
              value
              string))
      (error () string))))

(defun pd-atom (string)
  "Convert a Pd token STRING to a convenient assembly atom."
  (maybe-number string))

(defstruct canvas-builder
  name
  (width 1)
  (height 1)
  (elements nil)
  (connections nil)
  (declarations nil)
  (raw-records nil))

(defun builder-next-id (builder)
  (length (canvas-builder-elements builder)))

(defun builder-add-element (builder element)
  ;; Builders keep elements in Pd object-index order.
  (setf (canvas-builder-elements builder)
        (append (canvas-builder-elements builder) (list element)))
  element)

(defun finalize-builder (builder)
  (make-instance
   'pdel-asm:assembly-result
   :elements (canvas-builder-elements builder)
   :connections (nreverse (canvas-builder-connections builder))
   :declarations (nreverse (canvas-builder-declarations builder))
   :raw-records (nreverse (canvas-builder-raw-records builder))
   :width (canvas-builder-width builder)
   :height (canvas-builder-height builder)))

(defun parse-canvas-header (words)
  "Return NAME WIDTH HEIGHT from a #N canvas token list."
  (unless (and (>= (length words) 7)
               (string= (first words) "#N")
               (string= (second words) "canvas"))
    (error "Not a Pd canvas header: ~S" words))
  (let* ((width (or (maybe-number (fifth words)) 1))
         (height (or (maybe-number (sixth words)) 1))
         ;; Top-level: #N canvas x y w h font
         ;; Subpatch:  #N canvas x y w h name font
         (name (and (> (length words) 7)
                    (nth 6 words))))
    (values name width height)))

(defun make-parsed-element (builder type name x y args &key child raw)
  (let ((id (builder-next-id builder)))
    (builder-add-element
     builder
     (cond
       (child
        (make-instance 'pdel-asm:asm-subpatch
                       :id id :name name :type :subpatch
                       :args args :x x :y y :assembly child))
       (t
        (make-instance 'pdel-asm:asm-element
                       :id id :name name :type type
                       :args (if raw (list raw) args)
                       :x x :y y))))))

(defun parse-x-record (record words builder)
  "Consume one non-RESTORE #X record into BUILDER."
  (let ((kind (second words)))
    (cond
      ((string= kind "connect")
       (destructuring-bind (_x _connect source outlet destination inlet)
           words
         (declare (ignore _x _connect))
         (push (pdel-asm:make-connection
                :source (parse-integer source)
                :source-outlet (parse-integer outlet)
                :destination (parse-integer destination)
                :destination-inlet (parse-integer inlet))
               (canvas-builder-connections builder))))

      ((string= kind "declare")
       (push (mapcar (lambda (x)
                       (if (and (> (length x) 0) (char= (char x 0) #\-))
                           (pdel-symbol x)
                           (pd-atom x)))
                     (cddr words))
             (canvas-builder-declarations builder)))

      ((string= kind "obj")
       (let ((x (maybe-number (third words)))
             (y (maybe-number (fourth words)))
             (name (pdel-symbol (fifth words)))
             (args (mapcar #'pd-atom (nthcdr 5 words))))
         (make-parsed-element builder :object name x y args)))

      ((string= kind "msg")
       (let ((x (maybe-number (third words)))
             (y (maybe-number (fourth words)))
             (args (mapcar #'pd-atom (nthcdr 4 words))))
         (make-parsed-element builder :message (pdel-symbol "msg") x y args)))

      ((string= kind "text")
       (let ((x (maybe-number (third words)))
             (y (maybe-number (fourth words)))
             (text (format nil "~{~A~^ ~}" (nthcdr 4 words))))
         (make-parsed-element builder :text (pdel-symbol "text") x y (list text))))

      ((member kind '("floatatom" "symbolatom" "listbox") :test #'string=)
       (let ((x (maybe-number (third words)))
             (y (maybe-number (fourth words)))
             (type (intern (string-upcase kind) :keyword))
             (args (mapcar #'pd-atom (nthcdr 4 words))))
         (make-parsed-element builder type (pdel-symbol kind) x y args)))

      ;; COORDS and similar structural records must not consume an object id.
      ((member kind '("coords") :test #'string=)
       (push (concatenate 'string record ";")
             (canvas-builder-raw-records builder)))

      (t
       ;; Unknown #X records are conservatively represented as raw assembly
       ;; elements so later #X connect indices remain aligned.
       (let* ((maybe-x (and (> (length words) 2) (maybe-number (third words))))
              (maybe-y (and (> (length words) 3) (maybe-number (fourth words))))
              (x (if (numberp maybe-x) maybe-x 0))
              (y (if (numberp maybe-y) maybe-y 0)))
         (make-parsed-element builder :raw-element (pdel-symbol kind) x y nil
                              :raw (concatenate 'string record ";")))))))

(defun read-pd-string (text)
  "Parse Pure Data patch TEXT into a `pdel-asm:assembly-result'.
Nested `#N canvas' / `#X restore' records become ASM-SUBPATCH elements."
  (let ((stack nil)
        (root nil))
    (dolist (record (pd-statements text))
      (let ((words (pd-words record)))
        (cond
          ((and (>= (length words) 2)
                (string= (first words) "#N")
                (string= (second words) "canvas"))
           (multiple-value-bind (name width height)
               (parse-canvas-header words)
             (push (make-canvas-builder :name name :width width :height height)
                   stack)))

          ((and (>= (length words) 2)
                (string= (first words) "#X")
                (string= (second words) "restore"))
           (unless (>= (length stack) 2)
             (error "Unexpected #X restore outside a nested canvas"))
           (let* ((child-builder (pop stack))
                  (child (finalize-builder child-builder))
                  (parent (first stack))
                  (x (maybe-number (third words)))
                  (y (maybe-number (fourth words)))
                  (pd-pos (position "pd" words :test #'string=))
                  (name-string (or (and pd-pos (nth (1+ pd-pos) words))
                                   (canvas-builder-name child-builder)
                                   "subpatch"))
                  (name (pdel-symbol name-string)))
             (make-parsed-element parent :subpatch name x y nil :child child)))

          ((and stack (>= (length words) 2)
                (string= (first words) "#X"))
           (parse-x-record record words (first stack)))

          (stack
           ;; Preserve unknown top-level statements structurally.
           (push (concatenate 'string record ";")
                 (canvas-builder-raw-records (first stack))))

          (t
           (error "Pd record before #N canvas: ~A" record)))))

    (cond
      ((null stack) root)
      ((= (length stack) 1)
       (setf root (finalize-builder (pop stack)))
       root)
      (t
       (error "Unclosed nested Pd canvases (~D remain)" (length stack))))))

(defun read-pd-file (pathname)
  "Parse PATHNAME into a PDEL assembly."
  (read-pd-string (uiop:read-file-string pathname)))

;;;; Graph analysis ----------------------------------------------------------

(defun connectable-element-p (element)
  (not (member (pdel-asm:asm-element-type element)
               '(:text :raw-element))))

(defun element-map (assembly)
  (let ((table (make-hash-table :test #'eql)))
    (dolist (element (pdel-asm:assembly-elements assembly) table)
      (setf (gethash (pdel-asm:asm-element-id element) table) element))))

(defun incoming-map (assembly)
  (let ((table (make-hash-table :test #'equal)))
    (dolist (connection (pdel-asm:assembly-connections assembly) table)
      (push connection
            (gethash (cons (pdel-asm:connection-destination connection)
                           (pdel-asm:connection-destination-inlet connection))
                     table)))))

(defun outgoing-map (assembly)
  (let ((table (make-hash-table :test #'equal)))
    (dolist (connection (pdel-asm:assembly-connections assembly) table)
      (push connection
            (gethash (cons (pdel-asm:connection-source connection)
                           (pdel-asm:connection-source-outlet connection))
                     table)))))

(defun multioutlet-map (assembly)
  "Return a hash from node id to the distinct used outlets when there is more than one."
  (let ((multi (make-hash-table :test #'eql)))
    (dolist (element (pdel-asm:assembly-elements assembly) multi)
      (let ((outs (used-outlets assembly (pdel-asm:asm-element-id element))))
        (when (> (length outs) 1)
          (setf (gethash (pdel-asm:asm-element-id element) multi) outs))))))

(defun used-outlets (assembly id)
  (sort (remove-duplicates
         (loop for c in (pdel-asm:assembly-connections assembly)
               when (= id (pdel-asm:connection-source c))
                 collect (pdel-asm:connection-source-outlet c))
         :test #'=)
        #'<))

(defun node-variable (id)
  (local-symbol "N~D" id))

(defun outlet-variable (id outlet)
  (local-symbol "N~D-O~D" id outlet))

(defun element-constructor (element)
  "Return a PDEL form that creates ELEMENT without wiring inputs."
  (let ((name (pdel-asm:asm-element-name element))
        (args (pdel-asm:asm-element-args element))
        (type (pdel-asm:asm-element-type element)))
    (case type
      (:object
       (if args
           (list name (coerce args 'vector))
           (list name)))
      (:subpatch
       (if args
           (list name (coerce args 'vector))
           (list name)))
      (:message
       (list (pdel-symbol "msg") (coerce args 'vector)))
      (:floatatom
       (list (pdel-symbol "floatatom") (coerce args 'vector)))
      (:symbolatom
       (list (pdel-symbol "symbolatom") (coerce args 'vector)))
      (:listbox
       (list (pdel-symbol "listbox") (coerce args 'vector)))
      (:text
       (list (pdel-symbol "text") (or (first args) "")))
      (:raw-element
       ;; Unknown connectable Pd records cannot be reconstructed with RAW,
       ;; because RAW intentionally does not consume an object index.
       ;; Preserve the record visibly for manual handling.
       (list (pdel-symbol "raw-object") (or (first args) "")))
      (otherwise
       (error "Cannot disassemble element type ~S" type)))))

(defun source-reference (connection multioutlet-ids &optional inlet-bindings)
  "Return the PDEL expression naming CONNECTION's source endpoint."
  (let* ((id (pdel-asm:connection-source connection))
         (outlet (pdel-asm:connection-source-outlet connection))
         (inlet-name (and inlet-bindings (cdr (assoc id inlet-bindings :test #'=)))))
    (cond
      (inlet-name inlet-name)
      ((gethash id multioutlet-ids)
       (outlet-variable id outlet))
      ((zerop outlet)
       (node-variable id))
      (t
       (list (pdel-symbol "out") outlet (node-variable id))))))

(defun destination-reference (connection)
  (let ((id (pdel-asm:connection-destination connection))
        (inlet (pdel-asm:connection-destination-inlet connection)))
    (if (zerop inlet)
        (node-variable id)
        ;; IN is a PDEL macro alias for OUT and communicates intent better here.
        (list (pdel-symbol "in") inlet (node-variable id)))))

(defun edge-key-source (connection)
  (cons (pdel-asm:connection-source connection)
        (pdel-asm:connection-source-outlet connection)))

(defun edge-key-destination (connection)
  (cons (pdel-asm:connection-destination connection)
        (pdel-asm:connection-destination-inlet connection)))

(defun wire-forms (assembly &key omitted-ids inlet-bindings outlet-ids)
  "Return PDEL wire statements for ASSEMBLY.
FANOUT is preferred for one source endpoint with several destinations.  JOIN
is preferred for remaining many-to-one endpoint groups."
  (let* ((connections
           (remove-if
            (lambda (c)
              (or (and (member (pdel-asm:connection-source c) omitted-ids)
                       (not (assoc (pdel-asm:connection-source c)
                                   inlet-bindings :test #'=)))
                  (member (pdel-asm:connection-destination c) outlet-ids)))
            (pdel-asm:assembly-connections assembly)))
         (multi (multioutlet-map assembly))
         (handled (make-hash-table :test #'eq))
         (forms nil))
    ;; First consume true fan-out groups.
    (let ((by-source (make-hash-table :test #'equal)))
      (dolist (c connections)
        (push c (gethash (edge-key-source c) by-source)))
      (maphash
       (lambda (_key group)
         (declare (ignore _key))
         (when (> (length group) 1)
           (let ((ordered (sort (copy-list group) #'<
                                :key #'pdel-asm:connection-destination)))
             (push `(,(pdel-symbol "fanout")
                     ,(source-reference (first ordered) multi inlet-bindings)
                     ,@(mapcar #'destination-reference ordered))
                   forms)
             (dolist (c group) (setf (gethash c handled) t)))))
       by-source))

    ;; Then true fan-in among remaining edges.
    (let ((by-destination (make-hash-table :test #'equal)))
      (dolist (c connections)
        (unless (gethash c handled)
          (push c (gethash (edge-key-destination c) by-destination))))
      (maphash
       (lambda (_key group)
         (declare (ignore _key))
         (let ((ordered (sort (copy-list group) #'<
                              :key #'pdel-asm:connection-source)))
           (if (> (length ordered) 1)
               (push `(,(pdel-symbol "->")
                       (,(pdel-symbol "join")
                        ,@(mapcar (lambda (c)
                                    (source-reference c multi inlet-bindings))
                                  ordered))
                       ,(destination-reference (first ordered)))
                     forms)
               (let ((c (first ordered)))
                 (push `(,(pdel-symbol "->")
                         ,(source-reference c multi inlet-bindings)
                         ,(destination-reference c))
                       forms)))))
       by-destination))

    (values (nreverse forms) multi)))

(defun declarations-as-forms (assembly)
  (append
   (mapcar (lambda (args) `(,(pdel-symbol "declare") ,@args))
           (pdel-asm:assembly-declarations assembly))
   (mapcar (lambda (record) `(,(pdel-symbol "raw") ,record))
           (pdel-asm:assembly-raw-records assembly))))

(defun wrap-multiple-outlet-bindings (assembly body multi omitted-ids)
  "Wrap BODY in existing MULTIPLE-OUTLET-BIND macros where useful."
  (let ((result body))
    ;; Reverse id order so output is deterministic and lower ids are outermost.
    (dolist (element (reverse (pdel-asm:assembly-elements assembly)) result)
      (let* ((id (pdel-asm:asm-element-id element))
             (outs (gethash id multi)))
        (when (and outs (not (member id omitted-ids)))
          (let* ((max-out (apply #'max outs))
                 (names (loop for n from 0 to max-out
                              collect (outlet-variable id n))))
            (setf result
                  `((,(pdel-symbol "multiple-outlet-bind")
                     ,names ,(node-variable id)
                     ,@result)))))))))

(defun canonical-body (assembly &key inlet-bindings outlet-ids terminal)
  "Return a correctness-first PDEL body for ASSEMBLY.
INLET-BINDINGS maps child inlet element ids to formal symbols.  OUTLET-IDS are
child outlet elements that should be represented by `(outputs ...)' instead
of instantiated as ordinary nodes."
  (let* ((inlet-ids (mapcar #'car inlet-bindings))
         (omitted-ids (append inlet-ids outlet-ids))
         (nodes (remove-if
                 (lambda (e)
                   (or (member (pdel-asm:asm-element-id e) omitted-ids)
                       (eq (pdel-asm:asm-element-type e) :text)))
                 (pdel-asm:assembly-elements assembly)))
         (bindings
           (mapcar (lambda (e)
                     (list (node-variable (pdel-asm:asm-element-id e))
                           (element-constructor e)))
                   nodes))
         (side-forms
           (append
            (declarations-as-forms assembly)
            (loop for e in (pdel-asm:assembly-elements assembly)
                  when (and (not (member (pdel-asm:asm-element-id e) omitted-ids))
                            (eq (pdel-asm:asm-element-type e) :text))
                    collect (element-constructor e)))))
    (multiple-value-bind (wires multi)
        (wire-forms assembly
                    :omitted-ids inlet-ids
                    :inlet-bindings inlet-bindings
                    :outlet-ids outlet-ids)
      (let* ((last-node (and nodes
                             (node-variable
                              (pdel-asm:asm-element-id (car (last nodes))))))
             (body (append side-forms wires
                           (cond (terminal (list terminal))
                                 (last-node (list last-node))
                                 (t nil))))
             (body (if body body (list `(,(pdel-symbol "progn")))))
             (wrapped (wrap-multiple-outlet-bindings assembly body multi omitted-ids)))
        (if bindings
            `(,(pdel-symbol "let") ,bindings ,@wrapped)
            (if (= (length wrapped) 1)
                (first wrapped)
                `(,(pdel-symbol "progn") ,@wrapped)))))))

(defun inlet-elements (assembly)
  (remove-if-not
   (lambda (e)
     (member (string-downcase (symbol-name (pdel-asm:asm-element-name e)))
             '("inlet" "inlet~") :test #'string=))
   (pdel-asm:assembly-elements assembly)))

(defun outlet-elements (assembly)
  (remove-if-not
   (lambda (e)
     (member (string-downcase (symbol-name (pdel-asm:asm-element-name e)))
             '("outlet" "outlet~") :test #'string=))
   (pdel-asm:assembly-elements assembly)))

(defun signal-element-name-p (element prefix)
  (string= (string-downcase (symbol-name (pdel-asm:asm-element-name element)))
           (concatenate 'string prefix "~")))

(defun subpatch-definition (element)
  "Return a DEFPDEL form for parsed subpatch ELEMENT."
  (let* ((assembly (pdel-asm:asm-subpatch-assembly element))
         (ins (inlet-elements assembly))
         (outs (outlet-elements assembly))
         (in-bindings
           (loop for e in ins
                 for i from 0
                 collect (cons (pdel-asm:asm-element-id e)
                               (local-symbol "IN~D" i))))
         (input-specs
           (loop for e in ins
                 for i from 0
                 collect (list (local-symbol "IN~D" i)
                               (if (signal-element-name-p e "inlet")
                                   (pdel-symbol "signal")
                                   (pdel-symbol "control")))))
         (output-specs
           (loop for e in outs
                 for i from 0
                 collect (list (local-symbol "OUT~D" i)
                               (if (signal-element-name-p e "outlet")
                                   (pdel-symbol "signal")
                                   (pdel-symbol "control")))))
         (out-ids (mapcar #'pdel-asm:asm-element-id outs))
         (incoming (incoming-map assembly))
         (multi (multioutlet-map assembly))
         (output-forms
           (loop for out in outs
                 for edges = (gethash (cons (pdel-asm:asm-element-id out) 0)
                                      incoming)
                 collect
                 (cond
                   ((null edges) nil)
                   ((= (length edges) 1)
                    (source-reference (first edges) multi in-bindings))
                   (t `(,(pdel-symbol "join")
                        ,@(mapcar (lambda (c)
                                    (source-reference c multi in-bindings))
                                  (reverse edges)))))))
         (terminal `(,(pdel-symbol "outputs") ,@output-forms))
         (core (canonical-body assembly
                               :inlet-bindings in-bindings
                               :outlet-ids out-ids
                               :terminal terminal)))
    `(,(pdel-symbol "defpdel")
      ,(pdel-asm:asm-element-name element)
      ,input-specs
      :outputs ,output-specs
      ,core)))

(defun collect-subpatch-definitions (assembly)
  "Return recursive DEFPDEL forms required by ASSEMBLY."
  (let ((definitions nil)
        (seen (make-hash-table :test #'equal)))
    (labels ((walk (a)
               (dolist (e (pdel-asm:assembly-elements a))
                 (when (typep e 'pdel-asm:asm-subpatch)
                   (walk (pdel-asm:asm-subpatch-assembly e))
                   (let ((key (string-upcase
                               (symbol-name (pdel-asm:asm-element-name e)))))
                     (unless (gethash key seen)
                       (setf (gethash key seen) t)
                       ;; Prefer already-registered PDEL abstractions.  Their
                       ;; original DEFPDEL is more informative than an inferred
                       ;; definition from the .pd canvas.
                       (unless (pdel-compiler:find-object
                                (pdel-asm:asm-element-name e))
                         (push (subpatch-definition e) definitions))))))))
      (walk assembly))
    (nreverse definitions)))

(defun disassemble-assembly (assembly)
  "Return a DISASSEMBLY for ASSEMBLY."
  (make-disassembly
   :definitions (collect-subpatch-definitions assembly)
   :form (canonical-body assembly)))

(defun disassemble-pd-string (text)
  "Parse Pd TEXT and return a DISASSEMBLY."
  (disassemble-assembly (read-pd-string text)))

(defun disassemble-pd-file (pathname)
  "Parse a .pd file and return a DISASSEMBLY."
  (disassemble-assembly (read-pd-file pathname)))

(defun write-pdel-form (form stream)
  "Pretty-print FORM to STREAM in PDEL-LANG package context."
  (let ((*package* (find-package :pdel-lang))
        (*print-case* :downcase)
        (*print-pretty* t))
    (pprint form stream)))

(defun disassembly-to-string (disassembly)
  "Return DISASSEMBLY as readable Common Lisp/PDEL source."
  (with-output-to-string (out)
    (let ((*package* (find-package :pdel-lang))
          (*print-case* :downcase)
          (*print-pretty* t))
      (format out "(in-package #:pdel-lang)~%~%")
      (dolist (definition (disassembly-definitions disassembly))
        (pprint definition out)
        (terpri out)
        (terpri out))
      (pprint (disassembly-form disassembly) out)
      (terpri out))))

(defun write-disassembly (disassembly pathname)
  "Write DISASSEMBLY as PDEL source to PATHNAME and return PATHNAME."
  (ensure-directories-exist pathname)
  (with-open-file (stream pathname
                          :direction :output
                          :if-exists :supersede
                          :if-does-not-exist :create)
    (write-string (disassembly-to-string disassembly) stream))
  pathname)
