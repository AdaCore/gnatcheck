procedure Test is
   type Arr is array (1 .. 16) of Boolean;
   for Arr'Alignment use 4;

   type Der is new Arr;

   type Arr1 is array (1 .. 16) of Boolean;
   for Arr1'Alignment use 1;

   type Arr2 is array (1 .. 16) of Boolean;

   A  : Arr;
   D  : Der;
   A1 : Arr1;
   A2 : Arr2;

   S1 : constant Integer := A'Size;   --  FLAG
   S2 : constant Integer := D'Size;   --  FLAG
   S3 : constant Integer := A1'Size;  --  NOFLAG: alignment is 1
   S4 : constant Integer := A2'Size;  --  NOFLAG: no alignment clause
begin
   null;
end Test;
