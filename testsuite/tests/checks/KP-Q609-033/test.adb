with Ada.Real_Time.Timing_Events;

procedure Test is
   type Rec is record
      E : Ada.Real_Time.Timing_Events.Timing_Event;
   end record;

   type Plain is record
      I : Integer;
   end record;

   R : Rec;    --  FLAG
   P : Plain;  --  NOFLAG
begin
   null;
end Test;
