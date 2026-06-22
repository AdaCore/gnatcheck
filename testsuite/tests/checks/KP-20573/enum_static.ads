with Enum;

package Enum_Static is

   subtype DT_Sub is Enum.DT_Enum
   with Static_Predicate => DT_Sub in Enum.C | Enum.E | Enum.G;

end Enum_Static;
