--
--  Copyright (C) 2005-2026, AdaCore
--  SPDX-License-Identifier: GPL-3.0-or-later
--

--  This is the top of the Lkql_Checker hierarchy.

with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Fixed;

package Lkql_Checker is
   type Lkql_Checker_Mode is (Gnatcheck_Mode, Gnatkp_Mode);

   Mode : constant Lkql_Checker_Mode :=
     (if Ada.Strings.Fixed.Index
           (Ada.Directories.Simple_Name (Ada.Command_Line.Command_Name),
            "gnatkp")
        > 0
      then Gnatkp_Mode
      else Gnatcheck_Mode);
   --  The mode of the driver, either GNATcheck or GNATkp, derived from the
   --  name used to invoke the executable.
   --
   --  Declaring Mode as a constant initialized here (rather than a variable
   --  set later in Main) ensures that its value is available from the very
   --  first elaboration of this package.  Child packages such as
   --  Lkql_Checker.Options elaborate after their parent, so they see the
   --  correct Mode value when their own package-level generic instantiations
   --  are evaluated.

   function Lkql_Checker_Mode_Name (Mode : Lkql_Checker_Mode) return String
   is (case Mode is
         when Gnatcheck_Mode => "gnatcheck",
         when Gnatkp_Mode    => "gnatkp");
   --  Return the name associated to the given Mode.

   function Lkql_Checker_Mode_Image return String
   is (Lkql_Checker_Mode_Name (Mode));
   --  Get the Lkql_Checker_Mode image.
   --
   --  TODO: Use the Put_Image attribute for Lkql_Checker_Mode instead when
   --  switching to Ada_2022.

   procedure Main;
   --  Main entry point to Lkql_Checker.
end Lkql_Checker;
