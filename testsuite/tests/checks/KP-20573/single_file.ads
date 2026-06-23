--  Self-contained variant of the test: the statically predicated subtype and
--  the array aggregate referencing it through a qualified name both live in
--  the same source file, in two different (nested) packages.

package Single_File is

   package Inner_Enum is
      type DT_Enum is (A, B, C, D, E, F, G, H, I, J);
   end Inner_Enum;

   package Inner_Static is
      subtype DT_Sub is Inner_Enum.DT_Enum
      with
        Static_Predicate =>
          DT_Sub in Inner_Enum.C | Inner_Enum.E | Inner_Enum.G;
   end Inner_Static;

   subtype DT_Sub_Local is Inner_Enum.DT_Enum
   with
     Static_Predicate =>
       DT_Sub_Local in Inner_Enum.C | Inner_Enum.E | Inner_Enum.G;

   type XC_Array is array (Inner_Enum.DT_Enum) of Boolean;

   My_Wrong_Array : XC_Array :=
     (Inner_Static.DT_Sub => False, others => True); -- FLAG

   My_Correct_Array : XC_Array := (DT_Sub_Local => False, others => True); -- NOFLAG

end Single_File;
