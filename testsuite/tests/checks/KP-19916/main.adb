procedure Main is
   Dyn_Int : Integer := 131;
   Invalid_Size : constant Integer := 131;

   type Arr is array (1 .. 10) of Integer;

   type Arr_Valid_Comp_Size is array (1 .. 10) of Integer
   with Component_Size => 128;  -- NOFLAG

   type Arr_Low_Comp_Size is array (1 .. 10) of Integer
   with Component_Size => 61;  -- NOFLAG

   type Arr_Alligned_Comp_Size is array (1 .. 10) of Integer
   with Component_Size => 136;  -- NOFLAG

   type Arr_Dyn_Comp_Size is array (1 .. 10) of Integer
   with Component_Size => Dyn_Int;  -- NOFLAG

   type Arr_Invalid_Comp_Size is array (1 .. 10) of Integer
   with Component_Size => 131;  -- FLAG

   type Arr_Invalid_Comp_Size_Arith is array (1 .. 10) of Integer
   with Component_Size => 128 + 5;  -- FLAG

   type Arr_Invalid_Comp_Size_Const is array (1 .. 10) of Integer
   with Component_Size => Invalid_Size;  -- FLAG

   type Arr_Aspect_Decl is array (1 .. 10) of Integer;
   for Arr_Aspect_Decl'Component_Size use 131;  -- FLAG
begin
   null;
end Main;
