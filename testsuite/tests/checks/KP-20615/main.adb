with Pkg; use Pkg;

procedure Main is

   --  Bad_Set, a derived type in a declarative part, overrides its inherited
   --  Add_Unnamed operation (Include) with a body and no separate
   --  declaration: the override may be ineffective.
   type Bad_Set is new Set;

   procedure Include (S : in out Bad_Set; E : Integer) is  -- FLAG
   begin
      null;
   end Include;

   --  Same override, but with an explicit separate declaration (the
   --  documented workaround): not flagged.
   type Good_Set is new Set;

   procedure Include (S : in out Good_Set; E : Integer);

   procedure Include (S : in out Good_Set; E : Integer) is  -- NOFLAG
   begin
      null;
   end Include;

begin
   null;
end Main;
