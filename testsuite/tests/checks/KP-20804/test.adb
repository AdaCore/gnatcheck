procedure Test is
   Domain_Error : exception;

   subtype Positive_Even is Integer
   with
     Dynamic_Predicate => Positive_Even > 0 and then Positive_Even mod 2 = 0,
     Predicate_Failure => raise Domain_Error with "must be positive and even";

   Odd_Value : aliased Integer := 3;
   X         : Positive_Even;
   for X'Address use Odd_Value'Address;
   pragma Import (Ada, X);

   subtype Small is Integer
   with
     Static_Predicate  => Small in 1 | 3,
     Predicate_Failure => "expected 1 or 3";
   subtype Alias is Small;
   type Derived is new Alias;
   D : Derived := 1;
   S : Small := 3;

   subtype Nonzero is Integer
   with Predicate => Nonzero /= 0, Predicate_Failure => "zero";
   type Pair is record
      N : Nonzero;
   end record;
   P : Pair := (N => 1);

   subtype Even is Integer with Dynamic_Predicate => Even mod 2 = 0;
   E     : Even := 2;
   Valid : Boolean;
begin
   Valid := X'Valid;          -- FLAG
   Valid := S'Valid;          -- FLAG
   Valid := D'Valid;          -- FLAG
   Valid := P.N'vAlId;        -- FLAG
   Valid := E'Valid;          -- NOFLAG
   Valid := Odd_Value'Valid;  -- NOFLAG
   Valid := X'Size > 0;       -- NOFLAG
end Test;
