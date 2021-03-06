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

;************************** Cost of a Query ****************************

(defun CostQuery (Q)
   (prog (Cost)
      (PushMatchVar)
      (setq Cost (CostPred Q))
      (PopMatchVar)
      (return Cost)))


;************************* Cost of a Predicate *************************

(defun CostPred (P)
   (eval (Build
      (cond ((Match '(or (NE gEQ LT GT LE GE) > Expr1 > Expr2) P)
	 '(add
	    (FixedCosts 'Compare)
	    (CostExpr <q Expr1)
	    (CostExpr <q Expr2)))

       ((Match '(gNot > Pred) P)
	 '(CostPred <q Pred))

       ((Match '(In > ExprVar > C) P)
	 '(add
	    (FixedCosts 'In)
	    (CostExpr <q ExprVar)))

       ((Match '(Find ? ?) P)		;no scan entry
	 0.0)

       ((Match '(Find ? (All (Proj +) ?) >* FEList) P) 
                                                        ;projection required
         '(add
            99999999.
            (CostPred '(Find () (All) << FEList))))

       ((Match '(Find ? (All ? (Sort +)) >* FEList) P)
                                                        ;sort required
         '(add
            99999999.
            (CostPred '(Find () (All) << FEList))))

       ((Match
		  '(Find ? > FType (Scan ? (SubstituteVar > Expr)) >* Rest)
		  P)
	 '(add
	    (FixedCosts 'Bind)
	    (CostExpr <q Expr)
	    (CostPred '(Find () < FType << Rest))))

       ((Match
		  '(Find ? > FType
		     (Scan (? ? > C) (CondSubstitute > Expr)) >* Rest)
		  P)
	 '(add
	    (CostPred '(In < Expr < C))
	    (times
	       (ProbPred '(In < Expr < C))
	       (add
		  (FixedCosts 'Bind)
		  (CostPred '(Find () < FType << Rest))))))

       ((Match
		  '(Find ? > FType
		     (Scan > ExprVar
			(or (LookUp SCLookUp) > IName >* SelectCond))
		     >* Rest)
		  P)
	 '(add
	    (CostInit <q IName)
	    (CostSelect '(Scan < ExprVar (Iter < IName << SelectCond)))
	    (times
	       (min 1.0
		  (times
		     (SizeEst (IndexClass <q IName))
		     (ProbSelect
			'(Scan < ExprVar (Iter < IName << SelectCond)))))
	       (CostPred '(Find () < FType << Rest)))))

       ((Match
		  '(Find ? (One)
		     (Scan > ExprVar (? > IName >* SelectCond)) >* Rest)
		  P)

	 '(let* ((MaxIter
		     (times
			(SizeEst (IndexClass <q IName))
			(ProbSelect
			   '(Scan < ExprVar (Iter < IName << SelectCond)))))
		 (ProbRest
		     (ProbPred '(Find () (One) << Rest)))
		 (NumNextI
		     (if (zerop ProbRest)
			0.0
			(quotient
			   (diff
			      (diff 1.0 ProbRest)
			      (expt (diff 1.0 ProbRest) (add1 MaxIter)))
			   ProbRest)))
		 (NumRest
		     (if (zerop ProbRest)
			MaxIter
		      (if (zerop MaxIter)
			0.0
			(quotient
			   (diff 1.0
			      (expt (diff 1.0 ProbRest) MaxIter))
			   ProbRest)))))
	    (add
	       (CostInit <q IName)
	       (times
		  (add1 NumNextI)
		  (CostSelect '(Scan < ExprVar (Iter < IName << SelectCond))))
	       (times NumNextI
		  (CostCont <q IName))
	       (times NumRest
		  (CostPred '(Find () (One) << Rest))))))

       ((Match
		  '(Find ? (All *)
		     (Scan > ExprVar (? > IName >* SelectCond)) >* Rest)
		  P)

	 '(let* ((MaxIter
		     (times
			(SizeEst (IndexClass <q IName))
			(ProbSelect
			   '(Scan < ExprVar (Iter < IName << SelectCond))))))
	    (add
	       (CostInit <q IName)
	       (times
		  (add1 MaxIter)
		  (CostSelect '(Scan < ExprVar (Iter < IName << SelectCond))))
	       (times MaxIter
		  (add
		     (CostCont <q IName)
		     (CostPred '(Find () (All) << Rest)))))))

       ((Match '(Find ? > FType (ScanHeap) >* Rest) P)
	 '(CostPred '(Find () < FType << Rest)))

       ((Match '(Find ? ? (ScanHeap +) *) P)
	 0.0)

       ((Match '(Find ? > FType (AndHeap) >* Rest) P)
	 '(CostPred '(Find () < FType << Rest)))

       ((Match '(Find ? > FType (AndHeap >* PredList) >* Rest) P)
	 '(add
	    (CostPredList <q PredList)
	    (times
	       (ProbPredList <q PredList)
	       (CostPred '(Find () < FType << Rest)))))

       ((Match '(Find ? > FType (Cut *) >* Rest) P)
	 '(CostPred '(Find () < FType << Rest)))

       ((Match '(Find ? > FType > Pred >* Rest) P)
	 '(add
	    (CostPred <q Pred)
	    (times
	       (ProbPred <q Pred)
	       (CostPred '(Find () < FType << Rest)))))
))))


(defun CostSelect (ScanEntry)
   (funcall 'CostPredList (InterpretScan ScanEntry)))


(defun InterpretScan (ScanEntry &aux (ExprVar (cadr ScanEntry))
				     (ScanSpec (caddr ScanEntry)))
   (if (member (car ScanSpec) '(SubstituteVar CondSubstitute))
      `((gEQ ,ExprVar ,(cadr ScanSpec)))
      (do ((SCList (cddr ScanSpec) (cdr SCList))
	   (PredList nil))
	  ((null SCList) (reverse PredList))
	 (setq PredList (cons
            (case (caar SCList)
               (QualPF
	          `(gEQ (gApply ,ExprVar ,(cadar SCList)) ,(caddar SCList)))
               (QualSC
	          `(In ,ExprVar ,(cadar SCList))))
	    PredList)))))


;************ Cost of a Conjunctive List of Predicates *****************

(defun CostPredList (PredList)
   (funcall 'CostSorted
      (do ((Deterministic nil)
	   (Probabilistic nil)
	   (PredList PredList (cdr PredList)))
	  ((null PredList)
	    (append
	       (sort Deterministic #'lessp :key #'car)
	       (sort Probabilistic #'lessp :key #'car)))
	 (let* ((Cost (CostPred (car PredList)))
		(Prob (ProbPred (car PredList))))
	    (if (= 1 Prob)
	       (setq Deterministic
		  (cons
		     (list Cost Cost Prob)
		     Deterministic))
	       (setq Probabilistic
		  (cons
		     (list (quotient Cost (diff 1.0 Prob)) Cost Prob)
		     Probabilistic)))))))


(defun CostSorted (CList)
   (if (null CList)
      0.0
      (add
	 (cadar CList)
	 (times
	    (caddar CList)
	    (CostSorted (cdr CList))))))


;*********************** Cost of an Expression *************************

(defun CostExpr (E)
   (eval (Build
      (cond ((Match '(or (QVar PVar LVar EVar Constant) *) E)
	 '(FixedCosts 'Var))

       ((Match '(UnMinusOp > Expr) E)
	 '(add
	    (FixedCosts 'Add)
	    (CostExpr <q Expr)))

       ((Match '(or (AddOp SubOp) > Expr1 > Expr2) E)
	 '(add
	    (FixedCosts 'Add)
	    (CostExpr <q Expr1)
	    (CostExpr <q Expr2)))

       ((Match '(or (ModOp TimesOp DivOp) > Expr1 > Expr2) E)
	 '(add
	    (FixedCosts 'Multiply)
	    (CostExpr <q Expr1)
	    (CostExpr <q Expr2)))

       ((Match '(gApply ? > PF) E)
	 '(add
	    (FixedCosts 'Var)
	    (times
	       (FixedCosts 'Path)
	       (length <q PF))))))))


;******************** Costs of Operations on Indices *******************

(defun CostInit (IndexName)
   (case (IndexType IndexName)
      (List			10.0)
      (Array
	 (times			10.0
	    (log (SizeEst (IndexClass IndexName)))))
      (BinaryTree
	 (times			10.0
	    (log (SizeEst (IndexClass IndexName)))))
      (DistList			10.0)
      (DistPointer		10.0)
      (DistBinaryTree		10.0)))


(defun CostCont (IndexName)
   (case (IndexType IndexName)
      (List			0.5)
      (Array			0.5)
      (BinaryTree		1.0)
      (DistList			0.5)
      (DistPointer		0.0)
      (DistBinaryTree		1.0)))


;*********** Costs of Basic Operations (System Dependent) **************

(defun FixedCosts (Op)
   (case Op
      (Compare	1.0)	;cost of any comparisons
      (Var	0.5)	;cost of fetching a variable
      (Add	1.0)	;cost of adding operands
      (Multiply	2.0)	;cost of multiplying operands
      (Path	0.5)	;cost of finding a property of an entity
      (Bind	1.0)	;cost of a binding
      (In 	1.0)))	;cost of any isa check
			;cost of program branching ignored, ie cost of boolean
			;  operation ignored.


;**************** Probability Estimate of a Predicate ******************

(defun ProbPred (P)
   (eval (Build
      (cond ((Match '(gEQ > Expr1 > Expr2) P)
	 '(ProbEq <q Expr1 <q Expr2))

       ((Match '(GT > Expr1 > Expr2) P)
	 '(ProbGT <q Expr1 <q Expr2))

       ((Match '(GE > Expr1 > Expr2) P)
	 '(ProbGE <q Expr1 <q Expr2))

       ((Match '(LT > Expr1 > Expr2) P)
	 '(ProbGT <q Expr2 <q Expr1))

       ((Match '(LE > Expr1 > Expr2) P)
	 '(ProbGE <q Expr2 <q Expr1))

       ((Match '(NE > Expr1 > Expr2) P)
    '(ProbPred (gNot (gEQ <q Expr1 <q Expr2))))

       ((Match '(gNot > Pred) P)
	 '(diff 1.0 (ProbPred <q Pred)))

       ((Match '(In > ExprVar > C) P)
	 '(quotient
	    (float (CommonSize (ExpressionType <q ExprVar) <q C))
	    (SizeEst (ExpressionType <q ExprVar))))

       ((Match '(Find ? ?) P)		;no scan entry
	 1.0)

       ((Match '(Find ? ? (Scan ? (SubstituteVar ?)) >* Rest) P) 
	 '(ProbPred '(Find () (One) << Rest)))

       ((Match
		  '(Find ? ? (Scan (? ? > C) (CondSubstitute > Expr)) >* Rest)
		  P)
	 '(times
	    (ProbPred '(In < Expr < C))
	    (ProbPred '(Find () (One) << Rest))))

       ((Match
		  '(Find ? ?
		     (Scan > ExprVar
			(or (LookUp SCLookUp) > IName >* SelectCond))
		     >* Rest)
		  P)
	 '(times
	    (min 1.0
	       (times
		  (SizeEst (IndexClass <q IName))
		  (ProbSelect '(Scan < ExprVar (Iter < IName << SelectCond)))))
	    (ProbPred '(Find () (One) << Rest))))

       ((Match
		  '(Find ? ?
		     (Scan > ExprVar
			(or (Iter SCIter) > IName >* SelectCond))
		     >* Rest)
		  P)
	 '(let* ((MaxIter
		     (times
			(SizeEst (IndexClass <q IName))
			(ProbSelect
			   '(Scan < ExprVar (Iter < IName << SelectCond)))))
		 (ProbRest
		     (ProbPred '(Find () (One) << Rest))))
	    (if (zerop ProbRest)
	       0.0
	     (if (= 1 ProbRest)
	       1.0
	       (diff 1.0
		  (expt
		     (diff 1.0 ProbRest)
		     MaxIter))))))

       ((Match '(Find ? ? (ScanHeap) >* Rest) P)
	 '(ProbPred '(Find () (One) << Rest)))

       ((Match '(Find ? ? (ScanHeap +) *) P)
	 1.0)				 ;minimize cost of previous scans

       ((Match '(Find ? ? (AndHeap) >* Rest) P)
	 '(ProbPred '(Find () (One) << Rest)))

       ((Match '(Find ? ? (AndHeap >* PredList) >* Rest) P)
	 '(times
	    (ProbPredList <q PredList)
	    (ProbPred '(Find () (One) << Rest))))

       ((Match '(Find ? ? (Cut *) >* Rest) P)
	 '(ProbPred '(Find () (One) << Rest)))

       ((Match '(Find ? ? > Pred >* Rest) P)
	 '(times
	    (ProbPred <q Pred)
	    (ProbPred '(Find () (One) << Rest))))
))))


(defun ProbSelect (ScanEntry)
   (funcall 'ProbPredList (InterpretScan ScanEntry)))


(defun ProbPredList (PredList)
   (apply 'times (mapcar 'ProbPred PredList)))


;********************* Probability of an Equality **********************

(defun ProbEq (Expr1 Expr2)
   (let* ((T1 (ExpressionType Expr1)) (T2 (ExpressionType Expr2)))

      ;special case of "t1.p1.p* = t2.p2.p*"
      (cond ((and (eq (car Expr1) 'gApply)
	       (eq (car Expr2) 'gApply)
	       (eq (car (last (caddr Expr1))) (car (last (caddr Expr2)))))
	 (CondProb					;conditional probability
	    (ProbEq					; on if "t1.p1 = t1.p2"
	       (RemoveLastProp Expr1)
	       (RemoveLastProp Expr2))
	    1.0						;if yes, p*'s are equal
	    (case T1					;if no, use selectivity
	       ((String Real DoubleReal)
		  0.0)
	       (Integer
		  (quotient 1.0 (IntRangeSize (FindRange Expr1))))
	       (t
		  (quotient 1.0 (SizeEst T1))))))

      ;string comparison, case "t1.p1 = t2.p2"
       ((and (eq T1 'String)
		   (eq (car Expr1) 'gApply)
		   (eq (car Expr2) 'gApply))
	 (ProbEq					;the same conditional
	    (RemoveLastProp Expr1)			; probability again:
	    (RemoveLastProp Expr2)))			; t1 has to equal t2

      ;string comparison, case "t1.p1 = c or var"
       ((and (eq T1 'String)
		   (or (eq (car Expr1) 'gApply)
		       (eq (car Expr2) 'gApply)))
	 (quotient 1.0					;assuming one of the
	    (SizeEst (ExpressionType (RemoveLastProp		; t's in the class will
	       (if (eq (car Expr1) 'gApply)		; make the equality true
		  Expr1
		  Expr2))))))

      ;string comparison, case "c1 = c2"
       ((and (eq T1 'String)
		   (eq (car Expr1) 'Constant)
		   (eq (car Expr2) 'Constant))
	 (if (equal (Valof Expr1) (Valof Expr2))
	    1.0
	    0.0))

      ;string comparison, case "var = c or var"
       ((eq T1 'String)
	 0.0)

      ;real and double real comparison
       ((or (eq T1 'Real) (eq T1 'DoubleReal)
		  (eq T2 'Real) (eq T2 'DoubleReal))
	 (let* ((R1 (FindRange Expr1))			;not equal unless both
	        (R2 (FindRange Expr2)))			; are deterministically
	    (if (and (not (eq (car R1) 'Infinity))		; the same
		     (= (car R1) (cadr R1))
	             (= (car R1) (car R2))
	             (= (car R2) (cadr R2)))
	       1.0
	       0.0)))

      ;integer comparison
       ((eq T1 'Integer)
	 (let* ((R1 (FindRange Expr1))			;calculate ranges and
		(R2 (FindRange Expr2))			; find overlap, etc.
		(R1Size (IntRangeSize R1))
		(R2Size (IntRangeSize R2))
		(OvSize (IntRangeSize (RangeOverlap R1 R2))))
	    (if (and (eq R1Size 'Infinity) (eq R2Size 'Infinity))
	       0.0
	     (if (or (eq R1Size 'Infinity) (eq R2Size 'Infinity))
	       0.0
	       (quotient (float OvSize) R1Size R2Size)))))

      ;non-numerical comparison
	 (t (quotient					;find size of common
	    (float (CommonSize T1 T2))			; subclasses, etc.
	    (SizeEst T1)
	    (SizeEst T2))))))


;******************* Probability of an Inequality **********************

(defun ProbGT (Expr1 Expr2)
   (let* ((T1 (ExpressionType Expr1)) (T2 (ExpressionType Expr2)))
      (if (eq T1 'String)
	 0.5
       (if (or (eq T1 'Real) (eq T1 'DoubleReal)
                  (eq T2 'Real) (eq T2 'DoubleReal))
	 (ProbRealGT Expr1 Expr2)
	 (ProbIntGT Expr1 Expr2)))))


(defun ProbGE (Expr1 Expr2)
   (let* ((T1 (ExpressionType Expr1)) (T2 (ExpressionType Expr2)))
      (if (eq T1 'String)
	 0.5
       (if (or (eq T1 'Real) (eq T1 'DoubleReal)
                  (eq T2 'Real) (eq T2 'DoubleReal))
	 (ProbRealGT Expr1 Expr2)
	 (ProbIntGT `(AddOp ,Expr1 (Constant "1" Integer)) Expr2)))))


(defun ProbIntGT (Expr1 Expr2 &aux (R1 (FindRange Expr1))
				   (R2 (FindRange Expr2)))
   (if (member 'Infinity (append R1 R2)) 	;case variable involved
      0.5
      (let* ((A1 (minus (fix (minus (car R1))))) (A2 (fix (cadr R1)))
	     (B1 (minus (fix (minus (car R2))))) (B2 (fix (cadr R2))))
	 (cond ((> A1 B2)			;the general 6 cases
	    1.0)
	  ((and (not (< A1 B1)) (not (< A2 B2)))
	    (diff 1.0
	       (quotient
		  (float (Triang (- (1+ B2) A1)))
		  (float (* (- (1+ B2) B1) (- (1+ A2) A1))))))
	  ((not (< A1 B1))
	    (quotient
	       (float (+
		  (Triang (- A2 A1))
		  (* (- A1 B1) (- (1+ A2) A1))))
	       (float (* (- (1+ B2) B1) (- (1+ A2) A1)))))
	  ((not (> A2 B1))
	    0.0)
	  ((not (> A2 B2))
	    (quotient
	       (float (Triang (- A2 B1)))
	       (float (* (- (1+ B2) B1) (- (1+ A2) A1)))))
	  (t
	    (quotient
	       (float (+
		  (Triang (- B2 B1))
		  (* (- A2 B2) (- (1+ B2) B1))))
	       (float (* (- (1+ B2) B1) (- (1+ A2) A1)))))))))


(defun ProbRealGT (Expr1 Expr2 &aux (R1 (FindRange Expr1))
				    (R2 (FindRange Expr2)))
   (let* ((A1 (car R1)) (A2 (cadr R1))
	  (B1 (car R2)) (B2 (cadr R2)))
      (cond ((member 'Infinity (append R1 R2)) ;case variable involved
	 0.5)
       ((and (= A1 A2) (= B1 B2))	;cases constant(s) involved
	 (if (= A1 B1) 1.0 0.0))			; these are to avoid
       ((= A1 A2)			; division by zero
	 (quotient
	    (max 0.0 (diff A1 B1))
	    (diff B2 B1)))
       ((= B1 B2)
	 (quotient
	    (max 0.0 (diff A2 B1))
	    (diff A2 A1)))
       ((> A1 B2)			;the general 6 cases
	 1.0)
       ((and (> A1 B1) (> A2 B2))
	 (diff 1.0
	    (quotient
	       (quotient (Square (diff B2 A1)) 2.0)
	       (times (diff B2 B1) (diff A2 A1)))))
       ((> A1 B1)
	 (quotient
	    (add
	       (quotient (Square (diff A2 A1)) 2.0)
	       (times (diff A1 B1) (diff A2 A1)))
	    (times (diff B2 B1) (diff A2 A1))))
       ((< A2 B1)
	 0.0)
       ((< A2 B2)
	 (quotient
	    (quotient (Square (diff A2 B1)) 2.0)
	    (times (diff B2 B1) (diff A2 A1))))
       (t
	 (quotient
	    (add
	       (quotient (Square (diff B2 B1)) 2.0)
	       (times (diff A2 B2) (diff B2 B1)))
	    (times (diff B2 B1) (diff A2 A1)))))))


;*********************** Operations with Ranges ************************

(defun RangeOverlap (R1 R2 &aux (MinR1 (car R1)) (MaxR1 (cadr R1))
                                (MinR2 (car R2)) (MaxR2 (cadr R2)))
   (if (eq MinR1 'Infinity)
      R2
    (if (eq MinR2 'Infinity)
      R1
      `(,(max MinR1 MinR2) ,(min MaxR1 MaxR2)))))


(defun IntRangeSize (R &aux (MinR (car R)) (MaxR (cadr R)))
   (if (eq MinR 'Infinity)
      'Infinity
      (max 0 (+ (fix MaxR) (fix (minus MinR)) 1))))


;********** Finding the Range of an Arithmatical Expression ************

(defun FindRange (E)
   (case (car E)
      (Constant
	 `(,(float (Valof E)) ,(float (Valof E))))
      ((QVar PVar LVar EVar)
	 '(Infinity Infinity))
      (UnMinusOp
	 (let* ((R (FindRange (cadr E))))
	    (if (eq (car R) 'Infinity)
	       '(Infinity Infinity)
	       `(,(minus (cadr R)) ,(minus (car R))))))
      (AddOp
	 (let* ((R1 (FindRange (cadr E)))
	        (R2 (FindRange (caddr E))))
	    (if (member 'Infinity (append R1 R2))
	       '(Infinity Infinity)
	       (AddRanges R1 R2))))
      (SubOp
	 (FindRange `(AddOp ,(cadr E) (UnMinusOp ,(caddr E)))))
      (TimesOp
	 (let* ((R1 (FindRange (cadr E)))
	        (R2 (FindRange (caddr E))))
	    (if (member 'Infinity (append R1 R2))
	       '(Infinity Infinity)
	       (TimesRanges R1 R2))))
      (DivOp
	 (let* ((R1 (FindRange (cadr E)))
	        (R2 (FindRange (caddr E))))
	    (if (member 'Infinity (append R1 R2))
	       '(Infinity Infinity)
	       (DivRanges R1 R2))))
      (ModOp
	 (let* ((R1 (FindRange (cadr E)))
	        (R2 (FindRange (caddr E))))
	    (if (member 'Infinity R2)
	       '(Infinity Infinity)
	       (ModRanges R1 R2))))
      (gApply
	 (let* ((Prop (car (last (caddr E))))
		(PC (PropConstraint Prop)))
	    (if (eq (PropType Prop) 'Integer)
	       `(,(diff (cadr PC) 0.5) ,(add (caddr PC) 0.5))
	       `(,(float (cadr PC)) ,(float (caddr PC))))))))


(defun AddRanges (R1 R2 &aux (X1 (car R1)) (X2 (cadr R1))
                             (Y1 (car R2)) (Y2 (cadr R2)))
   (let* ((ZSum
	    (add X1 X2 Y1 Y2))
	  (ZDiff
	    (sqrt
	       (add
		  (Square (diff X1 X2))
		  (Square (diff Y1 Y2))))))
      `(,(quotient (diff ZSum ZDiff) 2.0) ,(quotient (add ZSum ZDiff) 2.0))))


(defun TimesRanges (R1 R2 &aux (X1 (car R1)) (X2 (cadr R1))
                               (Y1 (car R2)) (Y2 (cadr R2)))
   (let* ((XSum
	    (add X1 X2))
	  (YSum
	    (add Y1 Y2))
	  (XSqDiff
	    (Square (diff X1 X2)))
	  (YSqDiff
	    (Square (diff Y1 Y2)))
	  (ZSum
	    (quotient (times XSum YSum) 2.0))
	  (ZDiff
	    (sqrt
	       (add
		  (quotient (times XSqDiff YSqDiff) 12.0)
		  (quotient (times YSqDiff (Square XSum)) 4.0)
		  (quotient (times XSqDiff (Square YSum)) 4.0)))))
      `(,(quotient (diff ZSum ZDiff) 2.0) ,(quotient (add ZSum ZDiff) 2.0))))


(defun DivRanges (R1 R2 &aux (X1 (car R1)) (X2 (cadr R1))
                             (Y1 (car R2)) (Y2 (cadr R2)))
   (cond ((and (>= Y1 -0.5) (<= Y1 0.5) (>= Y2 -0.5) (<= Y2 0.5))	;Y1=Y2=0
      '(Infinity Infinity))

    ((and (= Y1 Y2) (> Y1 0))				;Y1=Y2>0
      `(,(quotient X1 Y1) ,(quotient X2 Y1)))

    ((= Y1 Y2)						;Y1=Y2<0
      `(,(quotient X2 Y1) ,(quotient X1 Y1)))

    ((or (>= Y1 0.5) (<= Y2 -0.5))				;0<Y1<Y2
      (let* ((ZSum							;  or
	       (quotient						;Y1<Y2<0
		  (times 
		     (add X1 X2)
		     (log (quotient Y2 Y1)))
		  (diff Y2 Y1)))
	     (ZDiff
	       (sqrt
		  (diff
		     (quotient
			(times 4.0
			   (add
			      (Square X1)
			      (times X1 X2)
			      (Square X2)))
			(times Y1 Y2))
		     (times 3.0 (Square ZSum))))))
	 `(,(quotient (diff ZSum ZDiff) 2.0)
	   ,(quotient (add ZSum ZDiff) 2.0))))

    ((>= Y1 -0.5)						;Y1=0,
      (DivRanges R1 `(0.5 ,Y2)))						;Y2>0

    ((<= Y2 0.5)						;Y1<0,
      (DivRanges R1 `(,Y1 -0.5)))					;Y2=0

    (t								;Y1<0,
      (let* ((Yrange (diff Y2 Y1 1.0))					;Y2>0
	     (ZSum
	       (quotient
		  (times 
		     (add X1 X2)
		     (log (minus (quotient Y2 Y1))))
		  Yrange))
	     (ZDiff
	       (sqrt
		  (diff
		     (times 4.0
			(add
			   (Square X1)
			   (times X1 X2)
			   (Square X2))
			(quotient
			   (add 4.0
			      (quotient 1.0 Y1)
			      (quotient 1.0 Y2))
			   Yrange))
		     (times 3.0 (Square ZSum))))))
	 `(,(quotient (diff ZSum ZDiff) 2.0)
	   ,(quotient (add ZSum ZDiff) 2.0))))))


(defun ModRanges (R1 R2)
   R1 ;the first argument is actually not used in the calculation, so ignore it.
   `(-0.5 ,(diff (quotient (add (abs (car R2)) (abs (cadr R2))) 2.0) 0.5)))


;***************************** Miscellaneous ***************************

(defun SizeEst (C)
   (apply 'add (mapcar 'RCntEst (SubClasses* C))))

(defun CommonSize (T1 T2)
   (apply 'add (mapcar 'RCntEst
      (SetIntersection (SubClasses* T1) (SubClasses* T2)))))

(defun CondProb (P C1 C2)
   (add
      (times C1 P)
      (times C2 (diff 1.0 P))))

(defun Triang (X)
   (/ (* X (1+ X)) 2))

(defun Square (X)
   (times X X))
