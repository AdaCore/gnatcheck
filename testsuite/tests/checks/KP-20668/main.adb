with System;

procedure Main is

   type Rev_Rec is tagged record
      A, B : Integer;
   end record;
   for Rev_Rec'Scalar_Storage_Order use System.High_Order_First;
   for Rev_Rec'Bit_Order use System.High_Order_First;

   type Ext_Rev_Rec is new Rev_Rec with record
      C : Integer;
   end record;

   type Rev_Rec_Aspect is record
      A, B : Integer;
   end record
   with
     Scalar_Storage_Order => System.High_Order_First,
     Bit_Order            => System.High_Order_First;

   type Norm_Rec is record
      A, B : Integer;
   end record;
   for Norm_Rec'Scalar_Storage_Order use System.Low_Order_First;

   type Native_Rec is record
      A, B : Integer;
   end record;
   for Native_Rec'Scalar_Storage_Order use System.Default_Bit_Order;

   type Plain_Rec is record
      A, B : Integer;
   end record;

   type Rev_Arr is array (1 .. 2) of Integer;
   for Rev_Arr'Scalar_Storage_Order use System.High_Order_First;

   type Inner is record
      C : Integer;
   end record;

   type Outer_Rec is record
      I : Inner;
      D : Integer;
   end record;
   for Outer_Rec'Scalar_Storage_Order use System.High_Order_First;
   for Outer_Rec'Bit_Order use System.High_Order_First;

   procedure P_Rev (X : Rev_Rec) is null;
   procedure P_Ext_Rev (X : Ext_Rev_Rec) is null;
   procedure P_Rev_Aspect (X : Rev_Rec_Aspect) is null;
   procedure P_Norm (X : Norm_Rec) is null;
   procedure P_Native (X : Native_Rec) is null;
   procedure P_Plain (X : Plain_Rec) is null;
   procedure P_Arr (X : Rev_Arr) is null;
   procedure P_Two (X, Y : Rev_Rec) is null;
   procedure P_Outer (X : Outer_Rec) is null;

   function Identity (X : Rev_Rec) return Rev_Rec
   is (X);

   C_Rev        : constant Rev_Rec := (A => 1, B => 2);
   C_Rev_Rename : Rev_Rec renames C_Rev;
   C_Rev_Delta  : constant Rev_Rec := (C_Rev with delta B => 3);
   C_Ext_Rev    : constant Ext_Rev_Rec :=
     (A => 1, B => (((2))), C => (Integer'(3)));
   C_Ext_Rev_P  : constant Ext_Rev_Rec := (C_Rev_Rename with C => 3);
   C_Rev_Aspect : constant Rev_Rec_Aspect := (A => 1, B => 2);
   C_Rev_Qual   : constant Rev_Rec := Rev_Rec'(A => 1, B => 2);
   C_Rev_Pos    : constant Rev_Rec := (1, 2);
   C_Norm       : constant Norm_Rec := (A => 1, B => 2);
   C_Native     : constant Native_Rec := (A => 1, B => 2);
   C_Plain      : constant Plain_Rec := (A => 1, B => 2);
   C_Arr        : constant Rev_Arr := (1, 2);

   V_Rev : Rev_Rec := (A => 1, B => 2);

   N                : Integer := 1;
   C_Rev_Dyn        : constant Rev_Rec := (A => N, B => 2);
   C_Rev_Dyn_Rename : Rev_Rec renames C_Rev_Dyn;
   C_Rev_Dyn_Delta  : constant Rev_Rec := (C_Rev_Dyn_Rename with delta B => 3);
   C_Ext_Rev_Dyn    : constant Ext_Rev_Rec := (C_Rev_Dyn_Rename with C => 3);

   C_Rev_Call : constant Rev_Rec := Identity ((A => 1, B => 2));

   C_Outer     : constant Outer_Rec := (I => (C => 1), D => 2);
   C_Outer_Dyn : constant Outer_Rec := (I => (C => N), D => 2);

begin
   P_Rev (C_Rev);                -- FLAG
   P_Rev (C_Rev_Delta);          -- FLAG
   P_Rev (C_Rev_Rename);         -- FLAG
   P_Ext_Rev (C_Ext_Rev);        -- FLAG
   P_Ext_Rev (C_Ext_Rev_P);      -- FLAG
   P_Rev_Aspect (C_Rev_Aspect);  -- FLAG: SSO specified with an aspect
   P_Rev (C_Rev_Qual);           -- FLAG
   P_Rev (C_Rev_Pos);            -- FLAG
   P_Two (C_Rev, C_Rev);         -- FLAG
   P_Outer (C_Outer);            -- FLAG: nested static aggregate

   P_Norm (C_Norm);              -- NOFLAG: same storage order as native
   P_Native (C_Native);          -- NOFLAG: default storage order
   P_Plain (C_Plain);            -- NOFLAG: no SSO aspect
   P_Arr (C_Arr);                -- NOFLAG: array type, not record
   P_Rev (V_Rev);                -- NOFLAG: not a constant
   P_Rev                         -- NOFLAG: non-static initialization expression
       (C_Rev_Dyn);
   P_Rev                         -- NOFLAG: non-static initialization expression
     (C_Rev_Dyn_Rename);
   P_Rev                         -- NOFLAG: non-static initialization expression
     (C_Rev_Dyn_Delta);
   P_Ext_Rev                     -- NOFLAG: non-static initialization expression
     (C_Ext_Rev_Dyn);
   P_Rev                         -- NOFLAG: initialization expression is not an aggregate
     (C_Rev_Call);
   P_Rev                         -- NOFLAG: aggregate passed directly, no named constant
     ((A => 1, B => 2));
   P_Outer (C_Outer_Dyn);        -- NOFLAG: nested non-static aggregate
end Main;
