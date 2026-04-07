--
--  Copyright (C) 2005-2026, AdaCore
--  SPDX-License-Identifier: GPL-3.0-or-later
--

--  This package provides report generation for GNATcheck.

package Lkql_Checker.Diagnostics.Report is

   procedure Generate_Qualification_Report
     (Collector : in out Diagnostic_Collector);
   --  Generate the report oriented for using as qualification
   --  materials. There is no parameter to configure this report except
   --  Lkql_Checker.Options.Short_Report flag.

   procedure Print_Report_Header;
   --  Generates the report header, including the date, tool version
   --  and tool command line invocation sequence. (We need it in spec
   --  because it is used by
   --  Lkql_Checker.Projects.Aggregate_Project_Report_Header.)

   procedure Process_User_Filename (Fname : String);
   --  Checks if Fname is the name of the existing file. If it is,
   --  sets it as the value of Lkql_Checker.Options.User_Info_File,
   --  otherwise generates warning and leaves User_Info_File unchanged.
   --  If User_Info_File is already set, and Fname denotes some
   --  existing file, generates a warning (user-defined part of the
   --  report file can be specified only once!) and leaves
   --  User_Info_File unchanged.

end Lkql_Checker.Diagnostics.Report;
