with Ada.Text_IO; use Ada.Text_IO;

procedure Operators is
   package Pkg is
      type T is record
         V : Integer;
      end record;

      function "+" (X, Y : T) return T;  -- FLAG

      function To_String (X : T) return String is (Integer'Image (X.V));
   end Pkg;

   package body Pkg is
      function "+" (X, Y : T) return T is
      begin
         if X.V = 0 then
            return Y;
         else
            declare
               N_X : constant T := (V => X.V - 1);
               N_Y : constant T := (V => Y.V + 1);
            begin
               return N_X + N_Y;
            end;
         end if;
      end "+";
   end Pkg;

   use Pkg;

   X : T := (V => 3);
   Y : T := (V => 4);
begin
   Put_Line (To_String (X + Y));
end Operators;
