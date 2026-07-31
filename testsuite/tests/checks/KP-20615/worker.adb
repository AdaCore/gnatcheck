with Pkg; use Pkg;

package body Worker is

   --  A package body is a declarative part too: Body_Set overrides its
   --  inherited Include with a body and no separate declaration, and is
   --  flagged just like a type in a subprogram's declarative part.
   type Body_Set is new Set;

   procedure Include (S : in out Body_Set; E : Integer) is  -- FLAG
   begin
      null;
   end Include;

   procedure Run is
      B : Body_Set;
   begin
      Include (B, 0);
   end Run;

end Worker;
