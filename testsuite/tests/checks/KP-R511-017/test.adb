procedure Test is
   type Bits is array (1 .. 16) of Boolean;
   pragma Pack (Bits);

   type Plain is array (1 .. 16) of Boolean;

   subtype Sub is Bits with Object_Size => 16;     --  FLAG
   subtype Sub2 is Plain with Object_Size => 128;  --  NOFLAG: not packed
   subtype Sub3 is Bits;                           --  NOFLAG: no Object_Size

   B : Sub;
begin
   null;
end Test;
