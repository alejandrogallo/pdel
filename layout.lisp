(in-package #:pdel-layout)

(defparameter *graphviz-dpi* 72.0d0)

(defun element-node-id (element)
  (format nil "node_~d" (pdel-asm:asm-element-id element)))

(defun element-label (element)
  (with-output-to-string (out)
    (write-string
     (string-downcase
      (symbol-name (pdel-asm:asm-element-name element)))
     out)
    (dolist (arg (pdel-asm:asm-element-args element))
      (format out " ~a" arg))))

(defun element->graphviz (element)
  `(,(element-node-id element)
    (:label ,(element-label element))
    (:shape :box)
    (:fontname "monospace")
    (:fontsize 12)
    (:margin "0.04,0.02")))

(defun connection->graphviz (connection)
  `(:->
    ((:dir "none")
     (:tooltip
      ,(format nil "outlet ~d -> inlet ~d"
               (pdel-asm:connection-source-outlet connection)
               (pdel-asm:connection-destination-inlet connection))))
    ,(format nil "node_~d" (pdel-asm:connection-source connection))
    ,(format nil "node_~d" (pdel-asm:connection-destination connection))))

(defun assembly->graphviz (assembly)
  `(:digraph "mus_pd"
    (= :rankdir "TB")
    (:graph
     (:overlap "false")
     (:splines "false")
     (:nodesep 0.20)
     (:ranksep 0.35))
    (:node
     (:fontname "monospace")
     (:fontsize 12)
     (:margin "0.04,0.02"))
    (:edge (:dir "none"))
    ,@(mapcar #'element->graphviz
              (pdel-asm:assembly-elements assembly))
    ,@(mapcar #'connection->graphviz
              (pdel-asm:assembly-connections assembly))))

(defun write-dot-file (assembly pathname)
  (ensure-directories-exist pathname)
  (with-open-file (stream pathname
                          :direction :output
                          :if-exists :supersede
                          :if-does-not-exist :create)
    (graphviz:format-graph
     (assembly->graphviz assembly)
     :stream stream))
  pathname)

(defun split-words (line)
  (uiop:split-string line
                     :separator '(#\Space #\Tab)))

(defun parse-real (string)
  (let ((*read-eval* nil))
    (multiple-value-bind (value position)
        (read-from-string string nil nil)
      (declare (ignore position))
      (unless (realp value)
        (error "Expected Graphviz real, got ~S" string))
      value)))

(defun graphviz-node-id->integer (name)
  (let ((prefix "node_"))
    (unless (and (>= (length name) (length prefix))
                 (string= name prefix :end1 (length prefix)))
      (error "Unexpected Graphviz node id ~S" name))
    (parse-integer name :start (length prefix))))

(defun run-dot-plain (dot-file)
  (uiop:run-program
   (list "dot" "-Tplain" (namestring dot-file))
   :output :string
   :error-output :interactive))

(defun apply-plain-layout (assembly plain-output)
  (let ((graph-width-in nil)
        (graph-height-in nil)
        (nodes nil))
    (dolist (line
             (uiop:split-string plain-output
                                :separator '(#\Newline)))
      (let ((fields (split-words line)))
        (when fields
          (cond
            ((string= (first fields) "graph")
             ;; graph SCALE WIDTH HEIGHT
             (setf graph-width-in  (parse-real (third fields))
                   graph-height-in (parse-real (fourth fields))))
            ((string= (first fields) "node")
             ;; node NAME X Y WIDTH HEIGHT ...
             (push (list :name   (second fields)
                         :x      (parse-real (third fields))
                         :y      (parse-real (fourth fields))
                         :width  (parse-real (fifth fields))
                         :height (parse-real (sixth fields)))
                   nodes))))))
    (unless (and graph-width-in graph-height-in)
      (error "Graphviz plain output contained no graph dimensions"))

    (let ((graph-width (* *graphviz-dpi* graph-width-in))
          (graph-height (* *graphviz-dpi* graph-height-in)))
      (setf (pdel-asm:assembly-width assembly) graph-width
            (pdel-asm:assembly-height assembly) graph-height)

      (dolist (node nodes)
        (let* ((id (graphviz-node-id->integer (getf node :name)))
               (element (pdel-asm:find-element-by-id assembly id)))
          (unless element
            (error "Unknown assembly element id ~D from Graphviz" id))
          (let* ((center-x (* *graphviz-dpi* (getf node :x)))
                 ;; Graphviz Y starts at the bottom; Pd starts at the top.
                 (center-y (- graph-height
                              (* *graphviz-dpi* (getf node :y))))
                 (width (* *graphviz-dpi* (getf node :width)))
                 (height (* *graphviz-dpi* (getf node :height))))
            (setf (pdel-asm:asm-element-center-x element) center-x
                  (pdel-asm:asm-element-center-y element) center-y
                  (pdel-asm:asm-element-x element)
                  (- center-x (/ width 2.0d0))
                  (pdel-asm:asm-element-y element)
                  (- center-y (/ height 2.0d0))
                  (pdel-asm:asm-element-width element) width
                  (pdel-asm:asm-element-height element) height)))))
      assembly))


(defun layout-with-dot-file (assembly dot-file)
  ;; Lay out nested subpatches first.  Their geometry is independent from the
  ;; parent graph, while the parent treats each subpatch as one ordinary node.
  (dolist (element (pdel-asm:assembly-elements assembly))
    (when (typep element 'pdel-asm:asm-subpatch)
      (layout (pdel-asm:asm-subpatch-assembly element))))
  (write-dot-file assembly dot-file)
  (apply-plain-layout assembly
                      (run-dot-plain dot-file)))

(defun layout (assembly)
  (let ((dot-file
          (merge-pathnames
           (make-pathname
            :name (format nil "pdel-layout-~d"
                          (random most-positive-fixnum))
            :type "dot")
           (uiop:temporary-directory))))
    (unwind-protect
         (layout-with-dot-file assembly dot-file)
      (when (probe-file dot-file)
        (delete-file dot-file)))))
