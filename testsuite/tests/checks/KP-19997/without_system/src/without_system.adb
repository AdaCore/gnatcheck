with Ada.Unchecked_Conversion;

with Interfaces;  use Interfaces;

procedure Without_System is
   function To_Bytes is new Ada.Unchecked_Conversion (Unsigned_32, Unsigned_32);  -- NOFLAG
begin
   null;
end Without_System;
