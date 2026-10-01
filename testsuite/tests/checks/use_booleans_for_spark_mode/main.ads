package Main is
   procedure Pragma_On_Non_Conflicting is null;
   pragma SPARK_Mode (On);    -- NOFLAG
   procedure Pragma_Off_Non_Conflicting is null;
   pragma SPARK_Mode (Off);   -- NOFLAG
   procedure Pragma_Auto_Non_Conflicting is null;
   pragma SPARK_Mode (Auto);  -- NOFLAG

   procedure Aspect_On_Non_Conflicting is null with SPARK_Mode => On;      -- NOFLAG
   procedure Aspect_Off_Non_Conflicting is null with SPARK_Mode => Off;    -- NOFLAG
   procedure Aspect_Auto_Non_Conflicting is null with SPARK_Mode => Auto;  -- NOFLAG

   --  Define symbols to hide spark On and Off
   On, Off, Auto : Boolean := False;

   procedure Pragma_On_Conflicting is null;
   pragma SPARK_Mode (On);    -- FLAG
   procedure Pragma_Off_Conflicting is null;
   pragma SPARK_Mode (Off);   -- FLAG
   procedure Pragma_Auto_Conflicting is null;
   pragma SPARK_Mode (Auto);  -- FLAG

   procedure Aspect_On_Conflicting is null with SPARK_Mode => On;      -- FLAG
   procedure Aspect_Off_Conflicting is null with SPARK_Mode => Off;    -- FLAG
   procedure Aspect_Auto_Conflicting is null with SPARK_Mode => Auto;  -- FLAG

   --  Ensure other pragmas aren't flagged

   pragma Assert (On);  -- NOFLAG

   --  Ensure that booleans aren't flagged

   procedure Pragma_True is null;
   pragma SPARK_Mode (True);   -- NOFLAG
   procedure Pragma_False is null;
   pragma SPARK_Mode (False);  -- NOFLAG

   procedure Aspect_True is null with SPARK_Mode => True;    -- NOFLAG
   procedure Aspect_False is null with SPARK_Mode => False;  -- NOFLAG

   --  Ensure the rule is handling the implicit notation

   procedure Aspect is null with SPARK_Mode;  -- NOFLAG
end Main;
