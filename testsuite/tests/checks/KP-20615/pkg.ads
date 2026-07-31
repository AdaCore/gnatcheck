package Pkg is

   type Set is private
     with Aggregate => (Empty       => Empty_Set,
                        Add_Unnamed => Include);

   function Empty_Set return Set;
   procedure Include (S : in out Set; E : Integer);

   --  A primitive that is not denoted by the Aggregate aspect.
   procedure Clear (S : in out Set);

private

   type Set is record
      Length : Natural := 0;
   end record;

end Pkg;
