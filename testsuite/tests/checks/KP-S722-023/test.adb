procedure Test is
   type Bits is array (Natural range <>) of Boolean;
   pragma Pack (Bits);

   B : Bits (0 .. 15);

   Slice : Bits renames B (0 .. 11);

   S1 : constant Integer := B (0 .. 11)'Size;  --  FLAG
   S2 : constant Integer := Slice'Size;        --  FLAG: renaming of a slice
   S3 : constant Integer := B'Size;            --  NOFLAG

   generic
      F : in out Bits;
      G : in Bits;
   procedure Gen;

   procedure Gen is
      S4 : constant Integer := F'Size;  --  FLAG: actual for F is a slice
      S5 : constant Integer := G'Size;  --  NOFLAG: formal of mode in
   begin
      null;
   end Gen;

   --  Only Inst is flagged: Whole instantiates Gen with full array actuals
   procedure Inst is new Gen (F => B (0 .. 11), G => B (0 .. 11));
   procedure Whole is new Gen (F => B, G => B);
begin
   null;
end Test;
