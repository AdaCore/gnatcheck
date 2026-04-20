with Q; use Q;

procedure P is

   procedure Test (Empty : Boolean) is
      -- The variable is not set by a conditional expression.
      Q : Rec := (D => False);  --  NOFLAG

      -- Conditional expression initializes one variable that is passed as an
      -- in-out parameter that triggers the bug.
      R : Rec :=
        (if Empty then (D => False) else (D => True, I => 0));  --  FLAG

      -- Conditional expression initializes multiple variables and one of them
      -- is passed as an in-out parameter that triggers the bug.
      S, T : Rec :=
        (if Empty then (D => False) else (D => True, I => 0));  --  FLAG

      -- Conditional expression initializes one variable but it is not passed as
      -- an in-out parameter. So the issue is not triggered in that case.
      U : Rec :=
        (if Empty then (D => False) else (D => True, I => 0));  --  NOFLAG

      -- Conditional expression initializes one variable that is renamed before
      -- being passed as an in-out parameter that triggers the bug.
      V : Rec :=
        (if Empty then (D => False) else (D => True, I => 0));  --  FLAG

      W : Rec renames V;

      -- Nested conditional expressions initialize one variable passed as an
      -- in-out parameter that triggers the bug (only outermost conditional
      -- expression is flagged).
      X : Rec :=
        (if Empty                                                      --  FLAG
         then (if Empty then (D => False) else (D => True, I => 0))
         else (if Empty then (D => False) else (D => True, I => 0)));

      -- Conditional expression initializes one variable that is passed as an
      -- in-out parameter but doesn't trigger the bug since the record
      -- discriminants have no defaults.
      Y : Rec_No_Default :=
        (if Empty then (D => False) else (D => True, I => 0));  --  NOFLAG

      -- Conditional expression initializes one variable that is passed as an
      -- in-out parameter that triggers the bug. This test uses a case
      -- expression instead of an if expression, as in the tests above.
      Z : Rec :=
        (case Empty is  --  FLAG
            when True  => (D => False),
            when False => (D => True, I => 0));

      -- Conditional expression initializes one variable that is passed as an
      -- in-out parameter that should trigger the bug but since the variable's
      -- type has no discriminant, it won't.
      A : Rec_No_Discr := (if Empty then (I => 0) else (I => 1));  --  NOFLAG

      -- Conditional expression initializes one variable that is passed as an
      -- in-out parameter that does not trigger the bug (the corresponding
      -- formal isn't written)
      B : Rec :=
        (if Empty then (D => False) else (D => True, I => 0));  --  NOFLAG
   begin
      Fill (Q);
      Fill (R);
      Fill (S);
      Fill (W);
      Fill (X);
      Fill (Y);
      Fill (Z);

      Read (U);
      Init (U);

      Fill(A);
      Fill2(B);
  end;

begin
   Test (True);
end;
