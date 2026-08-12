with System;
with Unchecked_Conversion;

procedure Main is
   type My_Float is digits 8;

   type Int_Arr is array (1 .. 1) of Integer;
   for Int_Arr'Scalar_Storage_Order use System.High_Order_First;

   type Int_Arr_Aspect is array (1 .. 1) of Integer
   with Scalar_Storage_Order => System.High_Order_First;

   type Int_Arr_Low_Order is array (1 .. 1) of Integer
   with Scalar_Storage_Order => System.Low_Order_First;

   type Int_Arr_Default_Order is array (1 .. 1) of Integer
   with Scalar_Storage_Order => System.Default_Bit_Order;

   type Int_Arr_No_Order is array (1 .. 1) of Integer;

   type Int_Rec is record
      I : Integer;
   end record;
   for Int_Rec'Scalar_Storage_Order use System.High_Order_First;

   function Int_Arr_To_Float is new  -- FLAG
     Unchecked_Conversion
       (Source => Int_Arr,
        Target => Float);

   function Int_Arr_To_Float_Positional is new  -- FLAG
     Unchecked_Conversion
       (Int_Arr,
        Float);

   function Int_Arr_To_My_Float is new  -- FLAG
     Unchecked_Conversion
       (Source => Int_Arr,
        Target => My_Float);

   function Int_Arr_To_Int is new  -- NOFLAG
     Unchecked_Conversion
       (Source => Int_Arr,
        Target => Integer);

   function Int_Arr_Aspect_To_Float is new  -- FLAG
     Unchecked_Conversion
       (Source => Int_Arr_Aspect,
        Target => Float);

   function Int_Arr_Low_Order_To_Float is new  -- NOFLAG
     Unchecked_Conversion
       (Source => Int_Arr_Low_Order,
        Target => Float);

   function Int_Arr_Default_Order_To_Float is new  -- NOFLAG
     Unchecked_Conversion
       (Source => Int_Arr_Default_Order,
        Target => Float);

   function Int_Arr_No_Order_To_Float is new  -- NOFLAG
     Unchecked_Conversion
       (Source => Int_Arr_No_Order,
        Target => Float);

   function Int_Rec_To_Float is new  -- NOFLAG
     Unchecked_Conversion
       (Source => Int_Rec,
        Target => Float);
begin
   null;
end Main;
