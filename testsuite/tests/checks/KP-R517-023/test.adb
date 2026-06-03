procedure Test is
   type Bit_Array is array (Natural range <>) of Boolean;
   pragma Pack (Bit_Array);

   type Rec is record
      F : Bit_Array (0 .. 7);
   end record;

   for Rec use record
      F at 0 range 0 .. 7;
   end record;

   type Rec_No_Rep is record
      F : Bit_Array (0 .. 7);
   end record;

   procedure P (A : out Bit_Array) is
   begin
      A := (others => False);
   end P;

   procedure Q (A : in Bit_Array) is
   begin
      null;
   end Q;

   procedure S (A : in out Bit_Array) is
   begin
      A := (others => False);
   end S;

   R  : Rec;
   RN : Rec_No_Rep;
begin
   P (R.F);   --  FLAG
   S (R.F);   --  FLAG: in out mode
   Q (R.F);   --  NOFLAG: in mode
   P (RN.F);  --  NOFLAG: no representation clause
end Test;
