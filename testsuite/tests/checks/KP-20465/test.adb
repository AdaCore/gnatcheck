procedure Test is

   type Rec is record
      I : Integer;
   end record;

   type Int_Arr is array (1 .. 10) of Integer;

   type Rec_Arr is array (1 .. 10) of Rec;

   type Arr_Of_Arr is array (1 .. 5) of Int_Arr;

   --
   --  Flag cases: non-constant array with composite component, declared in a
   --  subprogram and directly accessed in a nested subprogram.
   --

   procedure Proc_1 is
      A : Rec_Arr;               -- FLAG: record component, single nesting
      procedure Inner is
      begin
         A (1).I := 0;
      end Inner;
   begin
      Inner;
   end Proc_1;

   procedure Proc_2 is
      A : Arr_Of_Arr;            -- FLAG: array component, single nesting
      procedure Inner is
      begin
         A (1) (2) := 0;
      end Inner;
   begin
      Inner;
   end Proc_2;

   procedure Proc_3 is
      A : Rec_Arr;               -- FLAG: accessed in doubly-nested subprogram
      procedure Inner is
         procedure Inner_Inner is
         begin
            A (1).I := 0;
         end Inner_Inner;
      begin
         Inner_Inner;
      end Inner;
   begin
      Inner;
   end Proc_3;

   procedure Proc_4 is
      procedure Inner is
         A : Rec_Arr;       -- FLAG: declared in Inner, accessed in Inner_Inner
         procedure Inner_Inner is
         begin
            A (1).I := 0;
         end Inner_Inner;
      begin
         Inner_Inner;
      end Inner;
   begin
      Inner;
   end Proc_4;

   --
   --  No-flag cases.
   --

   procedure Proc_5 is
      A : Int_Arr;               -- NOFLAG: scalar (Integer) component
      procedure Inner is
      begin
         A (1) := 0;
      end Inner;
   begin
      Inner;
   end Proc_5;

   procedure Proc_6 is
      A : Rec_Arr;             -- NOFLAG: not accessed in any nested subprogram
   begin
      A (1).I := 0;
   end Proc_6;

   procedure Proc_7 is
      A : Rec_Arr;               -- NOFLAG: only passed as actual parameter
      procedure Inner (X : in out Rec_Arr) is
      begin
         X (1).I := 0;
      end Inner;
   begin
      Inner (A);
   end Proc_7;

   procedure Proc_8 is
      A : constant Rec_Arr := (others => (I => 0));  -- NOFLAG: constant
      V : Rec;
      procedure Inner is
      begin
         V := A (1);
      end Inner;
   begin
      Inner;
   end Proc_8;

begin
   null;
end Test;
