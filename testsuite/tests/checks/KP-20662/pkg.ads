package Pkg is

   type Pair is array (1 .. 2) of Character;

   type Buffer is array (Positive range <>) of Character;

   subtype Small_Buffer is Buffer (1 .. 2);

   --  first_bit values that are not multiples of Storage_Unit, below a storage
   --  unit for A, above it for B.

   type Nonaligned_Rec is record
      A : Pair;
      B : Pair;
   end record;

   for Nonaligned_Rec use record
      A at 0 range 4 .. 19;    --  FLAG
      B at 2 range 12 .. 27;   --  FLAG
   end record;

   --  first_bit values that are multiples of Storage_Unit, including C whose
   --  first_bit is nonzero and larger than a storage unit.

   type Aligned_Rec is record
      A : Pair;
      B : Pair;
      C : Pair;
   end record;

   for Aligned_Rec use record
      A at 0 range 0 .. 15;    --  NOFLAG
      B at 2 range 0 .. 15;    --  NOFLAG
      C at 1 range 24 .. 39;   --  NOFLAG
   end record;

   --  Only the nonaligned array component is flagged, neither the aligned one
   --  nor the nonaligned scalar one.

   type Mixed_Rec is record
      Aligned    : Pair;
      Nonaligned : Pair;
      Present    : Boolean;
   end record;

   for Mixed_Rec use record
      Aligned    at 0 range 0 .. 15;   --  NOFLAG
      Nonaligned at 2 range 1 .. 16;   --  FLAG
      Present    at 4 range 1 .. 1;    --  NOFLAG
   end record;

   --  Array type reached through a subtype of an unconstrained array type.

   type Subtype_Rec is record
      Data : Small_Buffer;
   end record;

   for Subtype_Rec use record
      Data at 0 range 1 .. 16;   --  FLAG
   end record;

   --  Representation clause on an untagged derived record type, whose
   --  component is inherited from the parent type.

   type Base_Rec is record
      A : Pair;
   end record;

   type Derived_Rec is new Base_Rec;

   for Derived_Rec use record
      A at 0 range 4 .. 19;   --  FLAG
   end record;

   --  No record representation clause, only a Pack aspect: out of the scope of
   --  the detector.

   type Packed_Rec is record
      Data  : Pair;      --  NOFLAG
      Count : Integer;   --  NOFLAG
   end record with Pack;

   --  Component types that are private in the visible part: only the one whose
   --  full view is an array type is nonaligned.

   type Hidden_Array is private;

   type Hidden_Char is private;

   type Private_Rec is record
      Arr  : Hidden_Array;
      Char : Hidden_Char;
   end record;

private

   type Hidden_Array is array (1 .. 2) of Character;

   type Hidden_Char is new Character;

   for Private_Rec use record
      Arr  at 0 range 4 .. 19;   --  FLAG
      Char at 4 range 4 .. 11;   --  NOFLAG
   end record;

end Pkg;
