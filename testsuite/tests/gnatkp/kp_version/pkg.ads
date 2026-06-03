package Pkg is
   type My_Bool is new Boolean;
   for My_Bool use (False => 0, True => 2);  -- FLAG (2)
end Pkg;
