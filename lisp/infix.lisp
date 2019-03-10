;  vim: set filetype=lisp tabstop=2 shiftwidth=2 expandtab :

;;; from https://raw.githubusercontent.com/peey/ugly-tiny-infix-macro/master/ugly-tiny-infix-macro.lisp
(defparameter *ops*
  '((* . 5)
    (/ . 5)
    (mod . 5)
    (rem . 5)
    (+ . 6)
    (- . 6)
    (ash . 7) ; bitshift
    (< . 8)
    (<= . 8)
    (> . 8)
    (>= . 8)
    (= . 9)
    (/= . 9)
    (eq . 9) ; for checking boolean equality
    (eql . 9) ; more ways for checking equality and returning a boolean
    (equal . 9)
    (bit-and . 10)
    (bit-xor . 11)
    (bit-ior . 12) ; ior = inclusive or = same as cpp's bitwise or
    ;bit-nor and bit-nand are available but I'm unsure where to put them in this list
    (had . 20)
    (and . 31)
    (or . 32)
    (then  . 90)
    (if  . 100)
    ))

(defmacro xpand(x)
  `(progn 
     (terpri) 
     (write 
       (macroexpand-1 ,x) :pretty t :right-margin 30 :case :downcase)
     (terpri)))


(define-condition malformed-infix-expression-error (error)
  ((text :initarg :text :reader malformed-infix-expression-error-text)
   (expression :initarg :expression :reader malformed-infix-expression-error-expression)))


;; from http://stackoverflow.com/a/7382977/1412255
(defmethod print-object ((err malformed-infix-expression-error) ostream)
  (print-unreadable-object (err ostream :type t)
    (format ostream "~s" (malformed-infix-expression-error-text err))
    (fresh-line ostream)
    (format ostream "Offending Expression: ~a" (malformed-infix-expression-error-expression err))))

;; for error checking
(defun check-lst (lst ops)
  (if (evenp (length lst))
    (error 'malformed-infix-expression-error :text 
           "Expression has an even length" 
           :expression lst))
  (if (not (loop for i from 1 below (length lst) by 2
                 always (not (null (assoc (nth i lst) ops)))))
    (error 'malformed-infix-expression-error :text "Not every element at odd index (even positions) in expression is a binary operator present in given *ops*"  :expression lst)))

(defun check-ops (ops)
  (if (not (and
             (listp ops)
             (not (null ops))
             (loop for item in ops
                   always (and (consp item) (symbolp (car item)) (numberp (cdr item))))))
    (error 'type-error :expected-type "non-empty-alist" :datum ops)))

;; returns values of  stack, list of popped elements
(defun recursively-pop-stack (stack element ops &optional (popped '()) )
  (if (and (not (null stack))
           (>=  (cdr (assoc element       ops)) 
                (cdr (assoc (first stack) ops))))
    ;; recursively pop stack
    (progn
      (setf popped (append popped (list (pop stack))))  
      ;; append to popped, not push, because order of returned 
      ;; popped stack should be same as was in working stack
      (recursively-pop-stack stack element ops popped))
    ;; else
    (values (push element stack) popped)))

;; apply popped operators to first two operands in q for each popped 
;; element (on top (index 0) of the stack should be the first operator to be applied)
(defun group (popped-stack q)
  ;; example operation:
  ;;input      : popped-stack  = (* -), q = (1 2 3)
  ;;iteration 1: popped-stack  = (-),   q = ((* 2 1) 3)
  ;;iteration 2: popped-stack  = (),    q = (- 3 (* 2 1))
  (loop for operator in popped-stack
        do
        (let ((b (pop q))
              (a (pop q)))
          (push (list operator a b) q)))
  q)

;; an implementation of shunting-yard algorithm for operators w/o parenthesis for grouping
(defun shunting-yard (lst &optional (ops  *ops*))
  (let (q stack) 
    (loop for element in lst
          do
          (if (assoc element ops)
            (multiple-value-bind (new-stack popped)
              (recursively-pop-stack stack element ops)
              (setf stack new-stack)
              (setf q (group popped q)))
            ;; if number / something that's expected to evaluated to a number
            (push element q)))
    ; append remaining stack to the q, get the single 
    ; expression left in the q of expressions
    (first (group stack q)))) 

(defmacro $ (&rest lst)
  "Infix binary operations for lisp!"
  (check-ops *ops*)
  (check-lst lst *ops*)
  (shunting-yard lst))

(xpand '($ emp = 23 had name = 'timm had age > 23 had salary < 23))
(xpand '($
  id = 31 
  if emp = 23 had name = 'timm had age > 23 had salary < 23 
  then name = 22 and ll = 21 and kk = 2
))

