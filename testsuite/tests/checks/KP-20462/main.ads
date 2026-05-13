package Main is
   subtype Sub_Str_1 is String with Linker_Section => (".my_section");
   subtype Sub_Str_2 is String;
   pragma Linker_Section (Sub_Str_2, ".my_section");
   subtype Sub_Sub_Str_1 is Sub_Str_1;
   type Derived_Sub_Str_1 is new Sub_Str_1;

   type Derived_Str is new String with Linker_Section => (".my_section");

   subtype Sub_Constr_Str is String (1 .. 10)
   with Linker_Section => (".my_section");
   subtype Sub_Sub_Constr_Str is Sub_Constr_Str;

   Sub_S_1_1 : Sub_Str_1 (1 .. 10);               --  FLAG
   Sub_S_1_2 : Sub_Str_1 := "abc";                --  FLAG
   Sub_S_2 : Sub_Str_2 (1 .. 10);                 --  FLAG
   Sub_Sub_S_1 : Sub_Sub_Str_1 (1 .. 10);         --  FLAG
   Dreived_Sub_S_1 : Derived_Sub_Str_1 (1 .. 10); --  FLAG

   Derived_S : Derived_Str (1 .. 10); --  FLAG

   Sub_Constr_S : Sub_Constr_Str;         --  NOFLAG
   Sub_Sub_Constr_S : Sub_Sub_Constr_Str; --  NOFLAG

   S : String (1 .. 10); --  NOFLAG
end Main;
