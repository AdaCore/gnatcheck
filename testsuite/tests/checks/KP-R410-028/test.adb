procedure Test is
   subtype Length is Natural range 0 .. 80;

   type Rec (D : Length := 0) is record
      S : String (1 .. D);
   end record;

   type Wrapper is record
      R : Rec;
   end record;

   function Make return Rec is
   begin
      return (D => 0, S => "");
   end Make;

   function Make_Wrapper return Wrapper is
   begin
      return (R => (D => 0, S => ""));
   end Make_Wrapper;

   function Count return Natural is
   begin
      return 10;
   end Count;
begin
   for I in 1 .. Make.D loop            --  FLAG
      null;
   end loop;

   for I in 1 .. Make_Wrapper.R.D loop  --  FLAG
      null;
   end loop;

   for I in 1 .. Count loop             --  NOFLAG
      null;
   end loop;
end Test;
