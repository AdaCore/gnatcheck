with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings.Text_Buffers;

procedure Attributes is
   package Pkg is
      type T is record
         X : Natural;
      end record
         with Put_Image => Custom_Image;

      procedure Custom_Image  -- FLAG
        (Output : in out Ada.Strings.Text_Buffers.Root_Buffer_Type'Class;
         Value  : T);
   end Pkg;

   package body Pkg is
      procedure Custom_Image
        (Output : in out Ada.Strings.Text_Buffers.Root_Buffer_Type'Class;
         Value  : T)
      is
      begin
         if Value.X > 0 then
            T'Put_Image (Output, (X => Value.X - 1));
            Output.Put (Value.X'Image);
         end if;
      end Custom_Image;
   end Pkg;

   X : constant Pkg.T := (X => 4);
begin
   Put_Line (X'Image);
end Attributes;
