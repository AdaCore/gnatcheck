procedure Calls is

   procedure Unknown with Import;

   function F return Integer is (1);

   Val : Integer := F;      --  NOFLAG

   type Proc_A is access procedure (X : Integer);
   X : Proc_A;

   type Proc_B is access procedure;
   Y : Proc_B;

   generic
      with procedure P_F;
   package P_G is
      X : Integer;
      procedure P;
   end P_G;

   package body P_G is
      procedure P is
      begin
         P_F;   --  NOFLAG
      end P;
   end P_G;

   package Ops is
      type T is null record;

      function "=" (X, Y : T) return Boolean
         with Import;
   end Ops;

begin
   Unknown;     --  FLAG
   X.all (1);   --  FLAG (2)
   X (1);       --  FLAG
   Y.all;       --  FLAG
   declare
      use Ops;
      Ops_Val : T;
      Dummy   : Boolean;
   begin
      Dummy := Ops_Val = Ops_Val;  --  FLAG
   end;
end Calls;
