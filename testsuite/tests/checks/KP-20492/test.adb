with System; use System;

procedure Test is

   type Angle is new Float range 0.0 .. 359.99;
   type Coord is new Long_Float;

   --
   --  Flag cases: array of floating-point type with non-default SSO.
   --

   type Arr_1 is array (1 .. 10) of Float  -- FLAG
     with Scalar_Storage_Order => System.High_Order_First;

   type Arr_2 is array (1 .. 10) of Angle  -- FLAG
     with Scalar_Storage_Order => System.High_Order_First;

   type Arr_3 is array (1 .. 10) of Long_Float;  -- FLAG
   for Arr_3'Scalar_Storage_Order use System.High_Order_First;

   type Arr_4 is array (1 .. 10) of Coord  -- FLAG
     with Scalar_Storage_Order => System.High_Order_First;

   --
   --  No-flag cases.
   --

   type Arr_No_SSO is array (1 .. 10) of Float;  -- NOFLAG: no SSO

   type Arr_Default_SSO is array (1 .. 10) of Float  -- NOFLAG: default SSO
     with Scalar_Storage_Order => System.Low_Order_First;

   type Arr_Int_SSO is array (1 .. 10) of Integer  -- NOFLAG: not float
     with Scalar_Storage_Order => System.High_Order_First;

   type Arr_Bool_SSO is array (1 .. 10) of Boolean  -- NOFLAG: not float
     with Scalar_Storage_Order => System.High_Order_First;

   type Rec_Float_SSO is record  -- NOFLAG: record, not array
      F : Float;
   end record
     with Scalar_Storage_Order => System.High_Order_First;

begin
   null;
end Test;
