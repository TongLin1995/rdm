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

;**************************** PASS FIVE ********************************
;***********************************************************************
; PassFive translates queries from low level ASL code generated from
; PassThree to readable PDM.  A LISP port is required as an argument,
; which can be allocated by using (fileopen FileName "w").
;***********************************************************************

(defun PassFive ()
   (PrintString "schema ")
   (PrintString Schema)
   (PrintLF)
   (PrintLF)
   (PrintClasses 'Entity () '**NoExtension**)
   (mapc 'PrintProperty Properties)
   (PrintLF)
   (mapc 'PrintIndex Indices)
   (mapc 'PrintStore Stores)
   (setq Queries (sort Queries 'string<))
   (mapc 'PrintQuery Queries)
   (setq Transactions (sort Transactions 'string<))
   (mapc 'PrintTransaction Transactions))


(defun PrintClasses (CName PNameList CExt)
   (if (UserClass? CName)
    (progn
      (PrintString "class ")
      (PrintString CName)
      (if (SupUserClasses CName)
         (progn (PrintString " isa ")
         (PrintIdList (SupUserClasses CName))))
      (PrintLF)
      (if (ClassUserProps CName)
         (progn (PrintString "properties ")
         (PrintIdList (ClassUserProps CName))
         (PrintLF)))
      (PrintString "msc ")
      (PrintString (ClassMscVal CName))
      (PrintString " mscsum ")
      (PrintString (ClassMscSumVal CName))
      (PrintLF)
      (PrintString "reference ")
      (case (ClassReference CName)
         (Pointer (PrintString "direct"))
         (IndPointer (PrintString "indirect")))
      (PrintLF)
      (if (not (eq CExt '**NoExtension**))
         (progn (PrintString "extension of ")
         (PrintString CExt)
         (PrintLF)))
      (setq PNameList (append PNameList (ClassProps CName)))
      (if PNameList 
         (progn (PrintString "fields")
         (PrintLF)
         (PrintIndent 1)
         (PrintString (car PNameList))
         (do ((FList (cdr PNameList) (cdr FList))) ((null FList))
            (PrintString ";")
            (PrintLF)
            (PrintIndent 1)
            (PrintString (car FList)))
         (PrintLF)))
      (PrintLF)
      (setq PNameList ())
      (setq CExt CName))
      (setq PNameList (append PNameList (ClassProps CName))))
   (do ((SubCList Classes (cdr SubCList))) ((null SubCList))
      (if (eq CName (ClassExtension (car SubCList)))
         (PrintClasses (car SubCList) PNameList CExt))))


(defun PrintProperty (PName)
   (PrintString "property ")
   (PrintString PName)
   (PrintString " on ")
   (PrintString (PropType PName))
   (if (PropConstraint PName)
      (case (car (PropConstraint PName))
         (Range
            (PrintString " range ")
            (PrintString (cadr (PropConstraint PName)))
            (PrintString " to ")
            (PrintString (caddr (PropConstraint PName))))
         (Maxlen
            (PrintString " maxlen ")
            (PrintString (cadr (PropConstraint PName))))))
   (PrintLF))


(defun PrintIndex (IName)
   (PrintString "index ")
   (PrintString IName)
   (PrintString " on ")
   (PrintString (IndexClass IName))
   (PrintLF)
   (PrintString "of type ")
   (case (IndexType IName)
      (List
         (PrintString "LIST"))
      (Array
         (PrintString "ARRAY")
         (PrintLF)
         (PrintString "with maximum size ")
         (PrintString (IndexSize IName))
         (PrintLF)
         (PrintString "ordered by ")
         (PrintSearchConds (IndexSearchConds IName)))
      (DistList
         (PrintString "DISTLIST")
         (PrintLF)
         (PrintString "distributed on ")
         (PrintPF (DistPF IName)))
      (DistPointer
         (PrintString "DISTPOINTER")
         (PrintLF)
         (PrintString "distributed on ")
         (PrintPF (DistPF IName)))
      (BinaryTree
         (PrintString "BINTREE")
         (PrintLF)
         (PrintString "ordered by ")
         (PrintSearchConds (IndexSearchConds IName)))
      (DistBinaryTree
         (PrintString "DISTBINTREE")
         (PrintLF)
         (PrintString "distributed on ")
         (PrintPF (DistPF IName))
         (PrintLF)
         (PrintString "ordered by ")
         (PrintSearchConds (cdr (IndexSearchConds IName)))))
   (PrintLF)
   (PrintLF))


(defun PrintSearchConds (SCList)
   (prog ()
    Loop
      (case (caar SCList)
         (PFCond
            (PrintPF (cadar SCList))
            (if (eq 'Asc (caddar SCList))
               (PrintString " asc")
               (PrintString " desc")))
         (SCCond
            (PrintString (cadar SCList))))
      (setq SCList (cdr SCList))
      (if (null SCList) (return t))
      (PrintString ", ")
      (go Loop)))


(defun PrintStore (SName &aux CList)
   (PrintString "store ")
   (PrintString SName)
   (PrintString " of type ")
   (case (StoreType SName)
      (Dynamic
         (PrintString "dynamic"))
      (Static
         (PrintString "static ")
         (PrintString (StoreSize SName))))
   (PrintLF)
   (PrintString "storing")
   (PrintLF)
   (setq CList (StoreClasses SName))
   (PrintIndent 1)
   (PrintString (car CList))
   (do ((CList (cdr CList) (cdr CList))) ((null CList))
      (PrintString ",")
      (PrintLF)
      (PrintIndent 1)
      (PrintString (car CList)))
   (PrintLF)
   (PrintLF))


(defun PrintQuery (QName)
   (let* ((QBody (QueryBody QName))
          (GivenVars (SelectVar (caddr QBody) '(PVar)))
          (QueryVars (SelectVar (caddr QBody) '(QVar)))
          (LocalVars (SelectVar (cdddadddr QBody) '(EVar))))
      (PrintString "query ")
      (PrintString QName)
      (PrintLF)
      (if GivenVars
         (progn (PrintString "given ")
         (PrintList GivenVars 'cadr)
         (if (lessp (length GivenVars) 3)
            (PrintString " from ")
          (progn
            (PrintLF)
            (PrintString "from ")))
         (PrintList GivenVars 'caddr)
         (PrintLF)))
      (PrintString "select ")
      (if (eq (car QBody) 'OneQuery) (PrintString "one "))
      (if QueryVars
         (progn (PrintList QueryVars 'cadr)
         (if (lessp (length QueryVars) 3)
            (PrintString " from ")
          (progn
            (PrintLF)
            (PrintString "from ")))
         (PrintList QueryVars 'caddr)))
      (PrintLF)
      (if LocalVars
         (progn (PrintString "declare ") (PrintList LocalVars 'cadr)
         (if (lessp (length LocalVars) 3)
            (PrintString " from ")
          (progn
            (PrintLF)
            (PrintString "from ")))
         (PrintList LocalVars 'caddr)
         (PrintLF)))
      (if (eq (caadddr QBody) 'Find)
         (PrintFindForm 0 (cadddr QBody))
         (PrintString "unoptimized"))
      (PrintLF)
      (PrintLF)))


(defun PrintFindForm (Indent FindForm)
   (if (Match '(? ? (All ? (Sort >+ OrderList)) *) FindForm)
      (progn (PrintString "sort ")
      (PrintSortSpec (GetBindVal 'OrderList))
      (PrintLF)
      (setq Indent (add1 Indent))
      (PrintIndent Indent)))
   (if (Match '(? ? (All (Proj >+ ProjList) ?) *) FindForm)
      (progn (PrintString "project ")
      (PrintList (GetBindVal 'ProjList) 'cadr)
      (PrintLF)
      (setq Indent (add1 Indent))
      (PrintIndent Indent)))
   (if (Match '(? ? ? (gNot ?)) FindForm)
      (progn (PrintSubForm Indent (cadddr FindForm))
      (PrintLF))
    (progn
      (PrintString "nest")
      (PrintLF)
      (do ((SubForms (cdddr FindForm) (cdr SubForms))) ((null SubForms))
         (PrintSubForm (add1 Indent) (car SubForms))
         (PrintString ";")
         (PrintLF))
      (PrintIndent (add1 Indent))
      (PrintString "end"))))


(defun PrintSortSpec (OrderList)
   (PrintExpr (caar OrderList))
   (if (eq 'Asc (cadar OrderList))
      (PrintString " asc")
      (PrintString " desc"))
   (do ((OrderList (cdr OrderList) (cdr OrderList))) ((null OrderList))
      (PrintString ", ")
      (PrintExpr (caar OrderList))
      (if (eq 'Asc (cadar OrderList))
         (PrintString " asc")
         (PrintString " desc"))))


(defun PrintSubForm (Indent SubForm)
   (PrintIndent Indent)
   (cond ((Match
	 '(Scan > ExprVar
	    (>or (SubstituteVar CondSubstitute) ScanType > Expr))
	 SubForm)
      (PrintString "assign ")
      (PrintExpr (GetBindVal 'ExprVar))
      (PrintString " as ")
      (PrintExpr (GetBindVal 'Expr))
      (if (eq (GetBindVal 'ScanType) 'CondSubstitute)
	 (progn (PrintString " in ")
	 (PrintString (caddr (GetBindVal 'ExprVar))))))

    ((Match
	    '(Scan > ExprVar
	       (>or (LookUp SCLookUp Iter SCIter) ScanType > IName >* SelCond))
	    SubForm)
      (PrintString "assign ")
      (PrintExpr (GetBindVal 'ExprVar))
      (PrintString " as ")
      (if (member (GetBindVal 'ScanType) '(LookUp SCLookUp))
	 (PrintString "first")
	 (PrintString "each"))
      (PrintString " of ")
      (PrintString (GetBindVal 'IName))
      (if (member (GetBindVal 'ScanType) '(SCLookUp SCIter))
	 (progn (PrintString " in ")
	 (PrintString (caddr (GetBindVal 'ExprVar)))))
      (if (GetBindVal 'SelCond)
	 (progn (PrintString " where")
	 (PrintLF)
	 (PrintSelCond (add1 Indent) SubForm))))

    ((Match '(Find *) SubForm)
      (PrintFindForm Indent SubForm))

    ((Match '(gNot (Find *)) SubForm)
      (PrintString "compliment")
      (PrintLF)
      (PrintIndent (add1 Indent))
      (PrintFindForm (add1 Indent) (cadr SubForm)))

    ((Match '(Cut > ExprVar) SubForm)
      (PrintString "cut ")
      (PrintExpr (GetBindVal 'ExprVar)))

    (t
      (PrintString "verify ")
      (PrintPred SubForm))))


(defun PrintPred (Pred)
   (case (car Pred)
      ((gEQ LT GT LE GE NE)
         (PrintExpr (cadr Pred))
         (case (car Pred)
	    (gEQ (PrintString " = "))
            (LT (PrintString " < "))
            (GT (PrintString " > "))
            (LE (PrintString " <= "))
            (GE (PrintString " >= "))
				(NE (PrintString " <> ")))
         (PrintExpr (caddr Pred)))
      ((In Is)
         (PrintExpr (cadr Pred))
         (case (car Pred)
            (In (PrintString " IN "))
            (Is (PrintString " IS ")))
         (PrintString (caddr Pred)))))


(defun PrintSelCond (Indent ScanEntry)
   (let* ((Conditions (InterpretScan ScanEntry)))
      (PrintIndent Indent)
      (PrintPred (car Conditions))
      (do ((Cond (cdr Conditions) (cdr Cond))) ((null Cond))
	 (PrintString ",")
	 (PrintLF)
	 (PrintIndent Indent)
	 (PrintPred (car Cond)))))


(defun PrintExpr (Expr)
   (case (car Expr)
      (Constant
         (if (eq 'String (caddr Expr))
            (PrintStringQuoted (cadr Expr))
            (PrintString (cadr Expr))))
      ((QVar PVar LVar EVar)
         (PrintString (cadr Expr)))
      (gApply
	 (PrintExpr (cadr Expr))
         (PrintString ".")
         (PrintPF (caddr Expr)))
      (UnMinusOp
	 (PrintString "(-")
	 (PrintExpr (cadr Expr))
	 (PrintString " )"))
      ((AddOp SubOp ModOp TimesOp DivOp)
	 (PrintString "(")
	 (PrintExpr (cadr Expr))
	 (PrintString
	    (cadr (assoc (car Expr)
	       '((AddOp " + ")(SubOp " - ")
		 (ModOp " % ")(TimesOp " * ")(DivOp " / ")))))
	 (PrintExpr (caddr Expr))
	 (PrintString ")"))
      (As
         (PrintString "(")
         (PrintExpr (cadr Expr))
         (PrintString " AS ")
         (PrintString (caddr Expr))
         (PrintString ")"))))


(defun PrintList (VarList Func)
   (PrintString (funcall Func (car VarList)))
   (do ((VList (cdr VarList) (cdr VList))) ((null VList))
      (PrintString ", ")
      (PrintString (funcall Func (car VList)))))


(defun PrintPF (Pf)
   (PrintString (car Pf))
   (do ((PfRest (cdr Pf) (cdr PfRest))) ((null PfRest))
      (PrintString ".")
      (PrintString (car PfRest))))


(defun PrintIdList (IdList)
   (PrintString (car IdList))
   (do ((Rest (cdr IdList) (cdr Rest))) ((null Rest))
      (PrintString ", ")
      (PrintString (car Rest))))


(defun PrintIndent (Indent)
   (do ((I Indent (sub1 I))) ((zerop I)) (PrintString "   ")))


(defun PrintString (String)
   (princ String PDMPort))


(defun PrintStringQuoted (String)
   (print String PDMPort))


(defun PrintLF ()
   (terpri PDMPort))


(defun PrintTransaction (TName)
   (let* ((Body (TransBody TName)))
      (PrintString "transaction ")
      (PrintString (cadr Body))
      (PrintLF)
      (if (caddr Body)
	 (progn (PrintString "given ")
	 (PrintList (caddr Body) 'cadr)
	 (PrintString " from ")
	 (PrintList (caddr Body) 'caddr)
	 (PrintLF)))
      (if (cadadddr Body)
	 (progn (PrintString "declare ")
	 (PrintList (cadadddr Body) 'cadr)
	 (PrintString " from ")
	 (PrintList (cadadddr Body) 'caddr)
	 (PrintLF)))
      (PrintString "actions")
      (PrintLF)
      (PrintIndent 1)
      (PrintStmt (cadddr Body) 1)
      (PrintLF)
      (if (eq (car Body) 'ExprTrans)
	 (progn (PrintString "return ")
	 (PrintExpr (caddddr Body))
	 (PrintLF)))
      (PrintLF)))


(defun PrintStmt (Stmt Indent)
   (case (car Stmt)
      (Assign
	 (PrintExpr (cadr Stmt))
	 (PrintString " := ")
	 (PrintExpr (caddr Stmt)))
      (AssignId
	 (PrintExpr (cadr Stmt))
	 (PrintString " id:= ")
	 (PrintExpr (caddr Stmt)))
      ((FreeId AllocId)
	 (PrintString (cadr (assoc (car Stmt)
	    '((FreeId "free id ") (AllocId "alloc id ")))))
	 (PrintExpr (cadr Stmt)))
      ((SInit IInit)
         (PrintString (cadr (assoc (car Stmt)
            '((SInit "init store ") (IInit "init index ")))))
         (PrintString (cadr Stmt)))
      (Copy
         (PrintString "copy ")
         (PrintExpr (cadddr Stmt))
         (PrintString " to ")
         (PrintExpr (caddr Stmt))
         (PrintString " for ")
         (PrintString (cadr Stmt)))
      ((Add Sub Cre Des Alloc Free IndirectAlloc IndirectFree)
	 (PrintString
	    (cadr (assoc (car Stmt) '(
	       (Add "insert ")
	       (Sub "remove ")
	       (Cre "create ")
	       (Des "destroy ")
	       (Alloc "allocate ")
	       (Free "free ")
	       (IndirectAlloc "allocate indirect ")
	       (IndirectFree "free indirect ")))))
	 (PrintExpr (caddr Stmt))
	 (PrintString
	    (cadr (assoc (car Stmt) '(
	       (Add " in ")
	       (Sub " from ")
	       (Cre " for ")
	       (Des " for ")
	       (Alloc " from ")
	       (Free " to ")
	       (IndirectAlloc " from ")
	       (IndirectFree " to ")))))
	 (PrintString (cadr Stmt)))
      (If
	 (PrintString "if ")
	 (PrintPred (cadr Stmt))
	 (PrintString " then")
	 (PrintLF)
	 (PrintIndent (add1 Indent))
	 (PrintStmt (caddr Stmt) (add1 Indent))
	 (if (cadddr Stmt)
	    (progn (PrintLF)
	    (PrintIndent Indent)
	    (if (eq (caadddr Stmt) 'If)
	     (progn
	       (PrintString "elseif")
	       (PrintStmt (cons 'ElseIf (cdadddr Stmt)) Indent))
	     (progn
	       (PrintString "else")
	       (PrintLF)
	       (PrintIndent (add1 Indent))
	       (PrintStmt (cadddr Stmt) (add1 Indent))))))
	 (PrintLF)
	 (PrintIndent Indent)
	 (PrintString "endif"))
      (ElseIf
	 (PrintPred (cadr Stmt))
	 (PrintString " then")
	 (PrintLF)
	 (PrintIndent (add1 Indent))
	 (PrintStmt (caddr Stmt) (add1 Indent))
	 (if (cadddr Stmt)
	    (progn (PrintLF)
	    (PrintIndent Indent)
	    (if (eq (caadddr Stmt) 'If)
	     (progn
	       (PrintString "elseif")
	       (PrintStmt (cons 'ElseIf (cdadddr Stmt)) Indent))
	     (progn
	       (PrintString "else")
	       (PrintLF)
	       (PrintIndent (add1 Indent))
	       (PrintStmt (cadddr Stmt) (add1 Indent)))))))
      (Block
	 (PrintStmt (caddr Stmt) Indent)
	 (do ((StmtList (cdddr Stmt) (cdr StmtList))) ((null StmtList))
	    (PrintString ";")
	    (PrintLF)
	    (PrintIndent Indent)
	    (PrintStmt (car StmtList) Indent)))))
