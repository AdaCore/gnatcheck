procedure Main is
   Buff : aliased String (1 .. 100);
   Addr : constant System.Address := Ident (Buff'Address);
   type Ints is array (1 .. 5) of Integer;

   procedure Array_With_Statically_Known_Constraint_Violation is
      X : constant Ints := (1 .. 4 => 123) with Address => Addr; --  FLAG
   begin
      pragma Assert (False);
   end Array_With_Statically_Known_Constraint_Violation;
begin
   null;
end Main;
