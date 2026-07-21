package body Pkg is

   function Empty_Set return Set is (Length => 0);

   procedure Include (S : in out Set; E : Integer) is
   begin
      S.Length := S.Length + 1;
   end Include;

   procedure Clear (S : in out Set) is
   begin
      S.Length := 0;
   end Clear;

end Pkg;
