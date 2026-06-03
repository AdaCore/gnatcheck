procedure Test is
   subtype Length is Natural range 0 .. 80;

   type Rec (D : Length := 0) is record
      C : Character;
      S : String (1 .. D);
   end record;
   pragma Pack (Rec);

   type Der (X : Length) is new Rec (D => X);   --  FLAG
   type Der2 is new Der (X => 10);              --  FLAG

   type Unpacked (D : Length := 0) is record
      S : String (1 .. D);
   end record;

   type Der3 is new Unpacked (D => 10);         --  NOFLAG

   type Tagged_Rec (D : Natural) is tagged record
      C : Character;
      S : String (1 .. D);
   end record;
   pragma Pack (Tagged_Rec);

   type Der4 is new Tagged_Rec (D => 10) with null record;  --  NOFLAG: tagged
begin
   null;
end Test;
