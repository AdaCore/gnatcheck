with Enum;
with Enum_Static;

package Multi_File is

   subtype DT_Booleano is Standard.Boolean;

   subtype DT_Sub_Local is Enum.DT_Enum
   with Static_Predicate => DT_Sub_Local in Enum.C | Enum.E | Enum.G;

   type XC_Array is array (Enum.DT_Enum) of DT_Booleano;

   My_Wrong_Array : XC_Array :=
     (Enum_Static.DT_Sub => False, others => True); -- FLAG

   My_Correct_Array : XC_Array := (DT_Sub_Local => False, others => True); -- NOFLAG

end Multi_File;
