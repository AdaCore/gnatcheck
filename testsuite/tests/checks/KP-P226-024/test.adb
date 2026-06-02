procedure Test is
   protected type PT is
      procedure Set;
   end PT;

   protected body PT is
      procedure Set is
      begin
         null;
      end Set;
   end PT;

   type Rec is record
      P : PT;
   end record;

   type Plain is record
      I : Integer;
   end record;

   R : Rec;    --  FLAG
   P : Plain;  --  NOFLAG
begin
   null;
end Test;
