with Pkg;

procedure Public_Part is

   --  Pub_Set is a derived type declared in a package specification, so the
   --  body-only Include below is not flagged even though it matches a denoted
   --  operation: the wrong-code cannot occur for a type declared in a spec.
   package Sets is
      type Pub_Set is new Pkg.Set;
   end Sets;

   procedure Include (S : in out Sets.Pub_Set; E : Integer) is  -- NOFLAG
   begin
      null;
   end Include;

begin
   null;
end Public_Part;
