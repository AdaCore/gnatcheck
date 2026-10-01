package Main is
   procedure Pragma_On_Non_Conflicting is null;
   pragma SPARK_Mode (On);    -- FLAG
   procedure Pragma_Off_Non_Conflicting is null;
   pragma SPARK_Mode (Off);   -- FLAG
   procedure Pragma_Auto_Non_Conflicting is null;
   pragma SPARK_Mode (Auto);  -- FLAG

   procedure Aspect_On_Non_Conflicting is null with SPARK_Mode => On;      -- FLAG
   procedure Aspect_Off_Non_Conflicting is null with SPARK_Mode => Off;    -- FLAG
   procedure Aspect_Auto_Non_Conflicting is null with SPARK_Mode => Auto;  -- FLAG

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
end Main;
