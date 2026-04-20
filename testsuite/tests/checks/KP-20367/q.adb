package body Q is

   procedure Fill (R : in out Rec) is
   begin
      R := (D => True, I => 1);
   end;

   procedure Fill2 (R : in out Rec) is
      Res : Rec;
   begin
      Res := R;
   end;

   procedure Fill (R : in out Rec_No_Default) is
   begin
      R := (D => True, I => 1);
   end;

   procedure Fill (R : in out Rec_No_Discr) is
   begin
      R := (I => 1);
   end;

end Q;
