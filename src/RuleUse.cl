;***********************************************************************
; Copyright (C) 1989, G. E. Weddell.
;
; This file is part of RDM.
;
; RDM is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; RDM is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with RDM.  If not, see <http://www.gnu.org/licenses/>.
;
;***********************************************************************

;*********************** REWRITE RULE CONTROL  *************************

;***********************************************************************
; ApplyRuleControl applies the rule control strategy specified as its
; first argument to its second argument form.   Control can be specified
; using the following constructs:
;
; <RuleName> - the rule called <RuleName> is applied.  Let the rule
;    be (<RuleName> <LeftHandSide> <RightHandSide> <Form>...)
;    If the given form matches with <LeftHandSide>, then
;    (1) each <Form> are built,
;    (2) each of the built forms are evaluated,
;    (3) <RightHandSide> is built, which replaces the given form.
;    However, if <RightHandSide> builds to nil, the given form
;    is not replaced by nil, but (nil) !!!
;    Returns t if rule applied, nil otherwise.
; (Call <StrategyName>) - the control strategy with the given name is
;    applied on the argument form.  Returns result of applying
;    <StrategyName>.
; (Not <Strategy>...) - <Strategy> is applied.  Returns logical negation
;    of result.
; (Or <Strategy>...) - each <Strategy> is applied in sequence, until
;    the first that successfully applies a rule.  Returns logical
;    disjunction of results.
; (And <Strategy>...) - each <Strategy> is applied in sequence,
;    until the first that fails to apply.  Returns logical conjunction
;    of results.
; (Seq <Strategy>...) - each <Strategy> is applied in sequence.  Returns
;    t if any of the <Strategy>'s is applied (i.e. logical disjuction).
; (Rep <Strategy>) - the argument <Strategy> is repetitively applied
;    until it no longer returns t.  Returns t if <Strategy> is applied
;    one or more than one time, nil if it is not applied.
; (If <Pattern> <Strategy>) - <Strategy> is applied if <Pattern>
;    matches the given form.  Returns t if <Pattern> is matched and
;    <Strategy> is applied.
; (Env c[ad]+r <Strategy>) - <Strategy> is applied on the c[ad]+r of
;    the given form.  Returns result of applying <Strategy>.
; (Map <Strategy>) - <Strategy> is applied on each element of the
;    given form.  Returns t only if <Strategy> is applied to each of
;    the elements (i.e. logical disjunction).
;***********************************************************************

; Set to list of rules to trace
(defvar TraceRules '())

(defun add (&rest args) (apply #'+ args))
(defun diff (&rest args) (apply #'- args))
(defun minus (&rest args) (apply #'- args))
(defun times (&rest args) (apply #'* args))
(defun quotient (&rest args) (apply #'/ args))
(defun lessp (&rest args) (apply #'< args))
(defun greaterp (&rest args) (apply #'> args))
(defun add1 (&rest args) (apply #'1+ args))
(defun sub1 (&rest args) (apply #'1- args))

(defun fix (&rest args) (apply #'truncate args))
(defun concat (&rest args)
   (read-from-string (concatenate 'string "|" (apply #'concatenate (cons 'string (mapcar #'symbol-name args))) "|")))

(defun ApplyRuleControl (Control Form)
   (cond
      ((atom Control)
         (PushMatchVar)
         (let ((Rule (get Control 'RWRule)) (Trace? (member Control TraceRules)))
            (if Trace? (Diagnostic `("*** Rule: " ,Control)))
            (if (Match (car Rule) Form)
               (prog (NewForm)
                  (mapc 'eval (mapcar 'Build (cddr Rule)))
                  (if Trace? (progn (princ "*** Initial is:" *error-output*) (pprint Form *error-output*) (terpri *error-output*)))
                  (setq NewForm (Build (cadr Rule)))
                  (rplaca Form (car NewForm))
                  (rplacd Form (cdr NewForm))
                  (if Trace? (progn (princ "*** Result is:" *error-output*) (pprint Form *error-output*) (terpri *error-output*)))
                  (PopMatchVar)
                  (return t))
               (progn
                  (if Trace? (progn (princ "*** Not Applied." *error-output*) (terpri *error-output*)))
                  (PopMatchVar)))))
      ((eq (car Control) 'Call)
         (ApplyRuleControl (get (cadr Control) 'RuleControl) Form))
      ((eq (car Control) 'Not)
         (not (ApplyRuleControl (cadr Control) Form)))
      ((eq (car Control) 'Or)
	 (do ((RuleList (cdr Control) (cdr RuleList)))
	     ((null RuleList) nil)
	    (if (ApplyRuleControl (car RuleList) Form) (return t))))
      ((eq (car Control) 'And)
	 (do ((RuleList (cdr Control) (cdr RuleList)))
	     ((null RuleList) t)
	    (if (not (ApplyRuleControl (car RuleList) Form)) (return nil))))
      ((eq (car Control) 'Seq)
	 (do ((RuleList (cdr Control) (cdr RuleList))
	      (Result nil))
	     ((null RuleList) Result)
	    (if (ApplyRuleControl (car RuleList) Form) (setq Result t))))
      ((eq (car Control) 'Rep)
	 (do ((Result nil t))
	     ((null (ApplyRuleControl (cadr Control) Form)) Result)))
      ((eq (car Control) 'If)
         (if (Match (cadr Control) Form)
            (ApplyRuleControl (caddr Control) Form)
            nil))
      ((eq (car Control) 'Env)
         (ApplyRuleControl (caddr Control) (funcall (cadr Control) Form)))
      ((eq (car Control) 'Map)
         (do ((FormList Form (cdr FormList))
	      (Result nil))
	     ((null FormList) Result)
	    (if (ApplyRuleControl (cadr Control) (car FormList))
	       (setq Result t))))))
         
;***********************************************************************
; LoadRules accepts a list of rules of the form:
;
; (<RuleName> <LeftHandSide> <RightHandSide> <Form>...)
;***********************************************************************

(defun LoadRules (RList)
   (mapc (function (lambda (Rule) (putprop (car Rule) (cdr Rule) 'RWRule))) RList))

;***********************************************************************
; LoadControl loads a rule control stategy for subsequent reference.
;***********************************************************************

(defun LoadControl (Control)
   (putprop (car Control) (cadr Control) 'RuleControl))
