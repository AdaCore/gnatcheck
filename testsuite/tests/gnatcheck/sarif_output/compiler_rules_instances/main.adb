with Ada.Calendar;  -- FLAG

procedure Main is
   Str : access String := new String'("hello");  -- FLAG
   Int : integer := 0;                           -- FLAG

   function Test (I : Integer) return Boolean is -- FLAG
   begin
      return False;
   end Test;

begin
   if int > 0 then  -- FLAG
      null;
   end if;

   if 1 = 1 then    -- FLAG
      null;
   end if;
end Main;
