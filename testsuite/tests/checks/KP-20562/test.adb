with Ada.Unchecked_Conversion;

procedure Test is
   type I is new Integer;
   type Vol_I is new Integer with Volatile;
   type Vol_I_Pragma is new Integer;
   pragma Volatile (Vol_I_Pragma);

   type D_Vol_I is new Vol_I;
   subtype S_Vol_I is Vol_I;

   type A_Integer is access all Integer;
   type A_I is access all I;
   type A_Vol_I is access all Vol_I;
   type A_D_Vol_I is access all D_Vol_I;
   type A_S_Vol_I is access all S_Vol_I;
   type A_Vol_I_Pragma is access all Vol_I_Pragma;

   function Int_To_I is new               -- NOFLAG
     Ada
       .Unchecked_Conversion
       (Source => A_Integer,
        Target => A_I);

   function Int_To_Vol_I_1 is new         -- FLAG
     Ada
       .Unchecked_Conversion
       (Source => A_Integer,
        Target => A_Vol_I);

   function Int_To_Vol_I_2 is new         -- FLAG
     Ada
       .Unchecked_Conversion
       (Target => A_Vol_I,
        Source => A_Integer);

   function Int_To_Vol_I_3 is new         -- FLAG
     Ada
       .Unchecked_Conversion
       (A_Integer,
        A_Vol_I);

   function Int_To_Vol_I_Pragma is new    -- FLAG
     Ada
       .Unchecked_Conversion
       (Source => A_Integer,
        Target => A_Vol_I_Pragma);

   function Int_To_S_Vol_I is new         -- FLAG
     Ada
       .Unchecked_Conversion
       (Source => A_Integer,
        Target => A_S_Vol_I);

   function Int_To_D_Vol_I is new         -- FLAG
     Ada
       .Unchecked_Conversion
       (Source => A_Integer,
        Target => A_D_Vol_I);

   function Vol_I_To_I is new             -- NOFLAG
     Ada
       .Unchecked_Conversion
       (Source => A_Vol_I,
        Target => A_Integer);

   function Vol_I_To_Vol_I_Pragma is new  -- NOFLAG
     Ada
       .Unchecked_Conversion
       (Source => A_Vol_I,
        Target => A_Vol_I_Pragma);

   function Non_Access_I_To_Vol_I is new  -- NOFLAG
     Ada
       .Unchecked_Conversion
       (Source => I,
        Target => Vol_I);
begin
   null;
end Test;
