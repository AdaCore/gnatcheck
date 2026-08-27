with Ada;

package Suffix is
   type Int   is range 0 .. 100;   -- FLAG
   type Int_T is range 0 .. 100;   -- NOFLAG

   type Int_A   is access Int;     -- NOFLAG
   type Int_PTR is access Int;     -- FLAG

   Const   : constant Int := 1;    -- FLAG
   Const_C : constant Int := 1;    -- NOFLAG

   package Renamed renames Ada;    -- FLAG
   package Renamed_R renames Ada;  -- NOFLAG
end Suffix;
