--
--  Copyright (C) 2005-2026, AdaCore
--  SPDX-License-Identifier: GPL-3.0-or-later
--

with Ada.Calendar;            use Ada.Calendar;
with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Directories;         use Ada.Directories;
with Ada.Exceptions;
with Ada.Strings;             use Ada.Strings;
with Ada.Strings.Fixed;       use Ada.Strings.Fixed;
with Ada.Text_IO;             use Ada.Text_IO;

with GNAT.OS_Lib;

with Lkql_Checker.Compiler;               use Lkql_Checker.Compiler;
with Lkql_Checker.Diagnostics.Exemptions;
use Lkql_Checker.Diagnostics.Exemptions;
with Lkql_Checker.Options;                use Lkql_Checker.Options;
with Lkql_Checker.Output;                 use Lkql_Checker.Output;
with Lkql_Checker.Rules.Rule_Table;       use Lkql_Checker.Rules.Rule_Table;
with Lkql_Checker.Source_Table;           use Lkql_Checker.Source_Table;
with Lkql_Checker.String_Utilities;       use Lkql_Checker.String_Utilities;

with GNATCOLL.Strings; use GNATCOLL.Strings;

package body Lkql_Checker.Diagnostics is

   --------------------------------------------
   -- Local routines for diagnostics storage --
   --------------------------------------------

   function Image (Self : Diagnostic) return String;

   procedure Compute_Statistics (Collector : in out Diagnostic_Collector);
   --  Computes the number of violations and diagnostics of different kinds.
   --  Results are stored in the corresponding counters in the package spec.
   --  Also computes file statistics and stores it in the following counters.

   Checked_Sources                  : Natural := 0;
   Unverified_Sources               : Natural := 0;
   Fully_Compliant_Sources          : Natural := 0;
   Sources_With_Violations          : Natural := 0;
   Sources_With_Exempted_Violations : Natural := 0;
   Ignored_Sources                  : Natural := 0;

   ------------------------------------------
   -- Local routines for report generation --
   ------------------------------------------

   Rule_List_File_Name_Str           : constant String := "-rule-list";
   Source_List_File_Name_Str         : constant String := "-source-list";
   Ignored_Source_List_File_Name_Str : constant String :=
     "-ignored-source-list";

   function Auxiliary_List_File_Name (S : String) return String;
   --  Should be used for getting the names of auxiliary files needed for
   --  GNATcheck report (list of processed sources, list of applied rules,
   --  list of ignored sources. Parameter specifies a substring to be included
   --  into the report file name to get the name of auxiliary file.

   Number : String_Access;
   pragma Unreferenced (Number);
   --  Used when processing individual projects as a part of aggregate project
   --  processing. Represents a numeric index (prepended by "_") that is
   --  taken from the report file name.

   procedure Copy_User_Info;
   --  Copies into the report file the text from user-provided file.

   function Escape_XML (S : String) return String;
   --  Escape relevant characters from S by their corresponding XML symbols

   procedure Print_Active_Rules_File;
   --  Prints the reference to the (actual argument or artificially created)
   --  file that contains the list of all the rules that are active for the
   --  given checker run.

   procedure Print_Argument_Files_Summary;
   --  Prints the total numbers of: all the argument files, non-compilable
   --  files, files with no violations, files with violations, files with
   --  exempted violations only.

   Diagnostics_To_Print :
     array (Rule_Violation .. Internal_Error) of Boolean := [others => False];
   --  Specifies which diagnostics should be printed out by the following
   --  procedure

   Print_Exempted_Violations : Boolean;
   --  Flag specifying if exempted or non-exempted violations should be
   --  printed. Has its effect only if Diagnostics_To_Print (Rule_Violation) is
   --  True.

   procedure Print_Diagnostics (Collector : in out Diagnostic_Collector);
   --  Iterates through all the diagnostics and prints into the report file
   --  those of them, for which Diagnostics_To_Print is True (and the value of
   --  Print_Exempted_Violations either corresponds to the diagnostic or is
   --  not applicable for the diagnostic kind).

   procedure Print_File_List_File;
   --  Prints the reference to the (actual argument or artificially created)
   --  file that contains the list of all the files passed to the checker.

   procedure Print_Ignored_File_List_File;
   --  Prints the reference to the artificially created file that contains the
   --  list of files passed to the checker that have not been processed
   --  because '--ignore=...' option. Note that it can be different from the
   --  list provided by '--ignore=...' option - this list contains only the
   --  existing files that have been passed as tool argument sources.

   procedure Print_Command_Line (XML : Boolean := False);
   --  Prints the command line used to run this Lkql_Checker instance. In case
   --  it has been called from the GNAT driver, prints the call to the GNAT
   --  driver, but not the call generated by the GNAT driver. If XML is ON,
   --  prints the output into XML output file, otherwise in the text output
   --  file.

   procedure Print_Out_Diagnostics (Collector : in out Diagnostic_Collector);
   --  Duplicates diagnostics about non-exempted rule violations, exemption
   --  warnings and compiler error messages into stderr. Up to value specified
   --  with the ``-m`` CLI option diagnostics are reported. If this value equal
   --  to 0, all the diagnostics of these kinds are reported.

   procedure Print_Runtime (XML : Boolean := False);
   --  Prints the runtime version used for the checker call. It is either the
   --  parameter of --RTS option used for the (actual) checker call or the
   --  "<default>" string if --RTS parameter is not specified. If XML is ON,
   --  prints the output into XML output file, otherwise - in the text output
   --  file.

   procedure Print_Violation_Summary;
   --  Prints the total numbers of: non-exempted)violations, exempted
   --  violations, exemption warnings and compiler errors.

   procedure XML_Report_Diagnostic (Diag : Diagnostic; Short_Report : Boolean);
   --  Prints into XML report file the information from the diagnostic. The
   --  boolean parameter is used to define the needed indentation level

   function Strip_Tag (Diag : String) return String;
   --  Strip trailing GNAT tag following the format " [-gnat<x>]", if any

   ------------------------------
   -- Auxiliary_List_File_Name --
   ------------------------------

   function Auxiliary_List_File_Name (S : String) return String is
      Prj_Out_File   : constant String :=
        (if Tool_Args.Text_Report_Enabled
         then Simple_Name (Tool_Args.Text_Report_File_Path)
         else Simple_Name (Tool_Args.XML_Report_File_Path));
      Prj_Out_First  : constant Natural := Prj_Out_File'First;
      Prj_Out_Last   : constant Natural := Prj_Out_File'Last;
      Prj_Out_Dot    : Natural := Index (Prj_Out_File, ".", Backward);
      Prj_Out_Suffix : constant String :=
        (if Prj_Out_Dot = 0
         then ""
         else Prj_Out_File (Prj_Out_Dot .. Prj_Out_Last));

      Suff_Start : Natural;
      Suff_End   : Natural;

   begin
      if Prj_Out_Dot = 0 then
         Prj_Out_Dot := Prj_Out_Last;
      else
         Prj_Out_Dot := Prj_Out_Dot - 1;
      end if;

      if GPR_Args.Aggregated_Project then
         --  in case of aggregated project we have to move the index in the
         --  Prj_Out_File after S. That is, we do not need
         --  <checker_mode>_1-source-list.out, we need
         --  <checker_mode>-source-list_1.out for the sake of upward
         --  compatibility.

         Suff_Start :=
           Index (Prj_Out_File (Prj_Out_First .. Prj_Out_Dot), "_", Backward);
         Suff_End := Prj_Out_Dot;

         return
           Prj_Out_File (Prj_Out_First .. Suff_Start - 1)
           & S
           & Prj_Out_File (Suff_Start .. Suff_End)
           & Prj_Out_Suffix;
      else

         return
           Prj_Out_File (Prj_Out_First .. Prj_Out_Dot) & S & Prj_Out_Suffix;
      end if;
   end Auxiliary_List_File_Name;

   ------------------------
   -- Compute_Statistics --
   ------------------------

   procedure Compute_Statistics (Collector : in out Diagnostic_Collector) is
      type Violations_Detected is record
         Exempted_Violations_Detected     : Boolean := False;
         Non_Exempted_Violations_Detected : Boolean := False;
      end record;

      File_Counter :
        array (First_SF_Id .. Last_Argument_Source) of Violations_Detected :=
          [others => (False, False)];

      procedure Count_Diagnostics (Position : Error_Messages_Storage.Cursor);

      procedure Count_Diagnostics (Position : Error_Messages_Storage.Cursor) is
         SF : constant SF_Id := Error_Messages_Storage.Element (Position).SF;
      begin
         if not Is_Argument_Source (SF) then
            --  All the statistics is collected for argument files only
            return;
         end if;

         case Error_Messages_Storage.Element (Position).Kind is
            when Rule_Violation    =>
               if Error_Messages_Storage.Element (Position).Justification
                 = Null_Unbounded_String
               then
                  Detected_Non_Exempted_Violations := @ + 1;
                  File_Counter (SF).Non_Exempted_Violations_Detected := True;
               else
                  Detected_Exempted_Violations := @ + 1;
                  File_Counter (SF).Exempted_Violations_Detected := True;
               end if;

            when Exemption_Warning =>
               Detected_Exemption_Warning := @ + 1;

            when Compiler_Error    =>
               Detected_Compiler_Error := @ + 1;

            when Internal_Error    =>
               Detected_Internal_Error := @ + 1;
         end case;
      end Count_Diagnostics;

   begin
      Collector.All_Error_Messages.Iterate (Count_Diagnostics'Access);

      for SF in First_SF_Id .. Last_Argument_Source loop
         if Source_Status (SF) in Not_A_Legal_Source | Error_Detected then
            Unverified_Sources := @ + 1;
         else
            Checked_Sources := @ + 1;

            if File_Counter (SF).Non_Exempted_Violations_Detected then
               Sources_With_Violations := @ + 1;
            elsif File_Counter (SF).Exempted_Violations_Detected then
               Sources_With_Exempted_Violations := @ + 1;
            elsif Source_Status (SF) = Processed then
               Fully_Compliant_Sources := @ + 1;
            end if;
         end if;
      end loop;
   end Compute_Statistics;

   --------------------
   -- Copy_User_Info --
   --------------------

   procedure Copy_User_Info is
      Max_Line_Len : constant Positive := 1024;
      Line_Buf     : String (1 .. Max_Line_Len);
      Line_Len     : Natural;
      User_File    : Ada.Text_IO.File_Type;
   begin
      --  Very simple-minded implementation...

      Open
        (File => User_File,
         Mode => In_File,
         Name => User_Info_File_Full_Path.all);

      loop
         exit when End_Of_File (User_File);

         Get_Line (File => User_File, Item => Line_Buf, Last => Line_Len);

         if Tool_Args.Text_Report_Enabled then
            Report (Line_Buf (1 .. Line_Len));
         end if;

         if Tool_Args.XML_Report_Enabled then
            XML_Report (Line_Buf (1 .. Line_Len), 1);
         end if;
      end loop;

      Close (User_File);
   exception
      when E : others =>

         Report_EOL;
         Report
           ("cannot successfully copy information from " & User_Info_File.all);

         if Is_Open (User_File) then
            Close (User_File);
         end if;

         Error
           ("cannot copy information from "
            & User_Info_File.all
            & " into report file");

         Print (Ada.Exceptions.Exception_Information (E));
   end Copy_User_Info;

   ----------------
   -- Escape_XML --
   ----------------

   function Escape_XML (S : String) return String is
      Result : Unbounded_String;
   begin
      for C of S loop
         case C is
            when '&'                   =>
               Append (Result, "&amp;");

            when '<'                   =>
               Append (Result, "&lt;");

            when '>'                   =>
               Append (Result, "&gt;");

            when '"'                   =>
               Append (Result, "&quot;");

            when ASCII.NUL .. ASCII.US =>
               declare
                  Img : constant String := Integer'Image (Character'Pos (C));
               begin
                  Append
                    (Result, "&#" & Img (Img'First + 1 .. Img'Last) & ";");
               end;

            when others                =>
               Append (Result, C);
         end case;
      end loop;

      return To_String (Result);
   end Escape_XML;

   ---------
   -- "<" --
   ---------

   function "<" (L, R : Diagnostic) return Boolean is
   begin
      return
        L.File < R.File
        or else (L.File = R.File and then L.Sloc < R.Sloc)
        or else (L.File = R.File
                 and then L.Sloc = R.Sloc
                 and then L.Text < R.Text);
   end "<";

   -----------------------------------
   -- Generate_Qualification_Report --
   -----------------------------------

   procedure Generate_Qualification_Report
     (Collector : in out Diagnostic_Collector)
   is
      use all type GNAT.OS_Lib.String_Access;
   begin
      Number := new String'(Get_Number);
      Ignored_Sources := Exempted_Sources;

      Process_Postponed_Exemptions (Collector);
      Compute_Statistics (Collector);

      if Tool_Args.XML_Report_Enabled then
         XML_Report ("<?xml version=""1.0""?>");
         XML_Report_No_EOL ("<gnatcheck-report");

         if Checker_Prj.Is_Specified then
            XML_Report
              (" project="""
               & (if GPR_Args.Aggregated_Project
                  then To_String (GPR_Args.Aggregate_Subproject.Get)
                  else Checker_Prj.Source_Prj)
               & """>");
         else
            XML_Report (">");
         end if;
      end if;

      --  OVERVIEW

      if not Tool_Args.Short_Report then
         Print_Report_Header;
         Print_Active_Rules_File;
         Print_File_List_File;
         Print_Ignored_File_List_File;
         Print_Argument_Files_Summary;

         if Tool_Args.Text_Report_Enabled then
            Report_EOL;
         end if;

         Print_Violation_Summary;

         --  2. DETECTED EXEMPTED RULE VIOLATIONS
         if Tool_Args.Text_Report_Enabled then
            Report_EOL;
            Report ("2. Exempted Coding Standard Violations");
            Report_EOL;
         end if;

         if Tool_Args.XML_Report_Enabled then
            XML_Report ("<violations>");
         end if;
      end if;

      if Detected_Exempted_Violations > 0 then
         Diagnostics_To_Print :=
           [Rule_Violation    => True,
            Exemption_Warning => False,
            Compiler_Error    => False,
            Internal_Error    => False];
         Print_Exempted_Violations := True;
         Print_Diagnostics (Collector);

      else
         if Tool_Args.Text_Report_Enabled then
            Report ("no exempted violations detected", 1);
         end if;

         if not Tool_Args.Short_Report and then Tool_Args.XML_Report_Enabled
         then
            XML_Report ("no exempted violations detected", 1);
         end if;
      end if;

      if not Tool_Args.Short_Report then
         if Tool_Args.Text_Report_Enabled then
            Report_EOL;
            Report ("3. Non-exempted Coding Standard Violations");
            Report_EOL;
         end if;
      end if;

      if Detected_Non_Exempted_Violations > 0 then
         Diagnostics_To_Print :=
           [Rule_Violation    => True,
            Exemption_Warning => False,
            Compiler_Error    => False,
            Internal_Error    => False];
         Print_Exempted_Violations := False;
         Print_Diagnostics (Collector);

      else
         if Tool_Args.Text_Report_Enabled then
            Report ("no non-exempted violations detected", 1);
         end if;

         if not Tool_Args.Short_Report and then Tool_Args.XML_Report_Enabled
         then
            XML_Report ("no non-exempted violations detected", 1);
         end if;
      end if;

      if not Tool_Args.Short_Report then
         if Tool_Args.Text_Report_Enabled then
            Report_EOL;
            Report ("4. Rule exemption problems");
            Report_EOL;
         end if;
      end if;

      if Detected_Exemption_Warning > 0 then
         Diagnostics_To_Print :=
           [Rule_Violation    => False,
            Exemption_Warning => True,
            Compiler_Error    => False,
            Internal_Error    => False];
         Print_Diagnostics (Collector);

      else
         if Tool_Args.Text_Report_Enabled then
            Report ("no rule exemption problems detected", 1);
         end if;

         if not Tool_Args.Short_Report and then Tool_Args.XML_Report_Enabled
         then
            XML_Report ("no rule exemption problems detected", 1);
         end if;

      end if;

      if not Tool_Args.Short_Report then
         if Tool_Args.Text_Report_Enabled then
            Report_EOL;
            Report ("5. Language violations");
            Report_EOL;
         end if;
      end if;

      if Detected_Compiler_Error > 0 then
         Diagnostics_To_Print :=
           [Rule_Violation    => False,
            Exemption_Warning => False,
            Compiler_Error    => True,
            Internal_Error    => False];
         Print_Diagnostics (Collector);

      else
         if Tool_Args.Text_Report_Enabled then
            Report ("no language violations detected", 1);
         end if;

         if not Tool_Args.Short_Report and then Tool_Args.XML_Report_Enabled
         then
            XML_Report ("no language violations detected", 1);
         end if;
      end if;

      if not Tool_Args.Short_Report then
         if Tool_Args.Text_Report_Enabled then
            Report_EOL;
            Report ("6. Gnatcheck internal errors");
            Report_EOL;
         end if;
      end if;

      if Detected_Internal_Error > 0 then
         Diagnostics_To_Print :=
           [Rule_Violation    => False,
            Exemption_Warning => False,
            Compiler_Error    => False,
            Internal_Error    => True];
         Print_Diagnostics (Collector);

      else
         if Tool_Args.Text_Report_Enabled then
            Report ("no internal error detected", 1);
         end if;

         if not Tool_Args.Short_Report and then Tool_Args.XML_Report_Enabled
         then
            XML_Report ("no internal error detected", 1);
         end if;
      end if;

      --  User-defined part

      if not Tool_Args.Short_Report then
         if Tool_Args.XML_Report_Enabled then
            XML_Report ("</violations>");
         end if;

         if Tool_Args.Text_Report_Enabled then
            Report_EOL;
         end if;

         if User_Info_File /= null then
            if Tool_Args.Text_Report_Enabled then
               Report ("7. Additional Information");
               Report_EOL;
            end if;

            if Tool_Args.XML_Report_Enabled then
               XML_Report ("<additional-information>");
            end if;

            Copy_User_Info;

            if Tool_Args.Text_Report_Enabled then
               Report_EOL;
            end if;

            if Tool_Args.XML_Report_Enabled then
               XML_Report ("</additional-information>");
            end if;
         end if;
      end if;

      if Tool_Args.XML_Report_Enabled then
         XML_Report ("</gnatcheck-report>");
      end if;

      --  Sending the diagnostics into Stderr

      if Tool_Args.Brief_Mode or not Tool_Args.Quiet_Mode then
         Print_Out_Diagnostics (Collector);
      end if;
   end Generate_Qualification_Report;

   -----------------------------
   -- Print_Active_Rules_File --
   -----------------------------

   procedure Print_Active_Rules_File is
      Rule_List_File : Ada.Text_IO.File_Type;
   begin
      if Tool_Args.Text_Report_Enabled then
         Report_No_EOL ("coding standard   : ");
      end if;

      if Tool_Args.XML_Report_Enabled then
         XML_Report_No_EOL
           ("<coding-standard from-file=""", Indent_Level => 1);
      end if;

      if not Individual_Rules_Set
        and then Legacy_Rule_File_Name /= Null_Unbounded_String
      then
         if Tool_Args.Text_Report_Enabled then
            Report (To_String (Legacy_Rule_File_Name));
         end if;

         if Tool_Args.XML_Report_Enabled then
            XML_Report (To_String (Legacy_Rule_File_Name) & """>");
         end if;
      else
         --  Creating the list of active rules

         declare
            Full_Rule_List_File_Name : constant String :=
              (if Tool_Args.Text_Report_File_Path /= ""
               then Containing_Directory (Tool_Args.Text_Report_File_Path)
               else Containing_Directory (Tool_Args.XML_Report_File_Path))
              & GNAT.OS_Lib.Directory_Separator
              & Auxiliary_List_File_Name (Rule_List_File_Name_Str);

         begin
            if GNAT.OS_Lib.Is_Regular_File (Full_Rule_List_File_Name) then
               Open (Rule_List_File, Out_File, Full_Rule_List_File_Name);
            else
               Create (Rule_List_File, Out_File, Full_Rule_List_File_Name);
            end if;

            for Cursor in All_Rule_Instances.Iterate loop
               Print_Rule_Instance_To_File
                 (All_Rule_Instances (Cursor).all, Rule_List_File);
               New_Line (Rule_List_File);
            end loop;

            --  Compiler-made checks:

            if Use_gnaty_Option then
               New_Line (Rule_List_File);
               Put_Line (Rule_List_File, "-- Compiler style checks:");
               Put (Rule_List_File, "+RStyle_Checks : ");
               Put_Line (Rule_List_File, Get_Specified_Style_Option);
            end if;

            if Use_gnatw_Option then
               New_Line (Rule_List_File);
               Put_Line (Rule_List_File, "--  Compiler warnings:");
               Put (Rule_List_File, "+RWarnings : ");
               Put_Line (Rule_List_File, Get_Specified_Warning_Option);
            end if;

            if Check_Restrictions then
               New_Line (Rule_List_File);
               Put_Line (Rule_List_File, "--  Compiler restrictions:");
               Print_Active_Restrictions_To_File (Rule_List_File);
            end if;

            Close (Rule_List_File);

            if Tool_Args.Text_Report_Enabled then
               Report (Auxiliary_List_File_Name (Rule_List_File_Name_Str));
            end if;

            if Tool_Args.XML_Report_Enabled then
               XML_Report
                 (Auxiliary_List_File_Name (Rule_List_File_Name_Str) & """>");
            end if;
         end;
      end if;

      if Tool_Args.XML_Report_Enabled then
         for Cursor in All_Rule_Instances.Iterate loop
            XML_Print_Rule_Instance (All_Rule_Instances (Cursor).all, 2);
         end loop;

         if Use_gnaty_Option then
            XML_Report ("<rule id=""Style_Checks"">", Indent_Level => 2);
            XML_Report
              ("<parameter>" & Get_Specified_Style_Option & "</parameter>",
               Indent_Level => 3);
            XML_Report ("</rule>", Indent_Level => 2);
         end if;

         if Use_gnatw_Option then
            XML_Report ("<rule id=""Warnings"">", Indent_Level => 2);
            XML_Report
              ("<parameter>" & Get_Specified_Warning_Option & "</parameter>",
               Indent_Level => 3);
            XML_Report ("</rule>", Indent_Level => 2);
         end if;

         if Check_Restrictions then
            XML_Print_Active_Restrictions (Indent_Level => 1);
         end if;

         XML_Report ("</coding-standard>", Indent_Level => 1);
      end if;
   end Print_Active_Rules_File;

   ----------------------------------
   -- Print_Argument_Files_Summary --
   ----------------------------------

   procedure Print_Argument_Files_Summary is
   begin

      if Tool_Args.Text_Report_Enabled then
         Report ("1. Summary");
         Report_EOL;

         Report
           ("fully compliant sources               :"
            & Fully_Compliant_Sources'Img,
            1);
         Report
           ("sources with exempted violations only :"
            & Sources_With_Exempted_Violations'Img,
            1);
         Report
           ("sources with non-exempted violations  :"
            & Sources_With_Violations'Img,
            1);
         Report
           ("unverified sources                    :" & Unverified_Sources'Img,
            1);
         Report
           ("total sources                         :"
            & Last_Argument_Source'Img,
            1);
         Report
           ("ignored sources                       :" & Ignored_Sources'Img,
            1);
      end if;

      if Tool_Args.XML_Report_Enabled then
         XML_Report ("<summary>");

         XML_Report
           ("<fully-compliant-sources>"
            & Image (Fully_Compliant_Sources)
            & "</fully-compliant-sources>",
            Indent_Level => 1);

         XML_Report
           ("<sources-with-exempted-violations-only>"
            & Image (Sources_With_Exempted_Violations)
            & "</sources-with-exempted-violations-only>",
            Indent_Level => 1);

         XML_Report
           ("<sources-with-non-exempted-violations>"
            & Image (Sources_With_Violations)
            & "</sources-with-non-exempted-violations>",
            Indent_Level => 1);

         XML_Report
           ("<unverified-sources>"
            & Image (Unverified_Sources)
            & "</unverified-sources>",
            Indent_Level => 1);

         XML_Report
           ("<total-sources>"
            & Image (Integer (Last_Argument_Source))
            & "</total-sources>",
            Indent_Level => 1);

      end if;

      pragma
        Assert
          (Checked_Sources
             = Fully_Compliant_Sources
               + Sources_With_Violations
               + Sources_With_Exempted_Violations
               + Ignored_Sources);
      pragma
        Assert
          (Natural (Last_Argument_Source)
             = Checked_Sources + Unverified_Sources);
   end Print_Argument_Files_Summary;

   -----------------------
   -- Print_Diagnostics --
   -----------------------

   procedure Print_Diagnostics (Collector : in out Diagnostic_Collector) is

      procedure Print_Specified_Diagnostics
        (Position : Error_Messages_Storage.Cursor);
      --  Print the given message if relevant.
      --  Iterator for Error_Messages_Storage

      ---------------------------------
      -- Print_Specified_Diagnostics --
      ---------------------------------

      procedure Print_Specified_Diagnostics
        (Position : Error_Messages_Storage.Cursor)
      is
         Diag : constant Diagnostic :=
           Error_Messages_Storage.Element (Position);
      begin
         if Diagnostics_To_Print (Diag.Kind) then
            if Diag.Kind = Rule_Violation
              and then Print_Exempted_Violations
                       = (Diag.Justification = Null_Unbounded_String)
            then
               return;
            end if;

            if Tool_Args.Text_Report_Enabled then
               Report (Strip_Tag (Image (Diag)));

               if Diag.Justification /= Null_Unbounded_String then
                  Report ("(" & To_String (Diag.Justification) & ")", 1);
               end if;
            end if;

            if Tool_Args.XML_Report_Enabled then
               XML_Report_Diagnostic (Diag, Tool_Args.Short_Report);
            end if;
         end if;
      end Print_Specified_Diagnostics;

   begin
      Collector.All_Error_Messages.Iterate
        (Print_Specified_Diagnostics'Access);
   end Print_Diagnostics;

   --------------------------
   -- Print_File_List_File --
   --------------------------

   procedure Print_File_List_File is
      Source_List_File : Ada.Text_IO.File_Type;
   begin
      if Tool_Args.Text_Report_Enabled then
         Report_No_EOL ("list of sources   : ");
      end if;

      if Tool_Args.XML_Report_Enabled then
         XML_Report_No_EOL ("<sources from-file=""", Indent_Level => 1);
      end if;

      --  Creating the list of processed sources

      declare
         Full_Source_List_File_Name : constant String :=
           (if Tool_Args.Text_Report_File_Path /= ""
            then Containing_Directory (Tool_Args.Text_Report_File_Path)
            else Containing_Directory (Tool_Args.XML_Report_File_Path))
           & GNAT.OS_Lib.Directory_Separator
           & Auxiliary_List_File_Name (Source_List_File_Name_Str);

      begin
         if Tool_Args.XML_Report_Enabled then
            XML_Report
              (Auxiliary_List_File_Name (Source_List_File_Name_Str) & """>");
         end if;

         if GNAT.OS_Lib.Is_Regular_File (Full_Source_List_File_Name) then
            Open (Source_List_File, Out_File, Full_Source_List_File_Name);
         else
            Create (Source_List_File, Out_File, Full_Source_List_File_Name);
         end if;

         for SF in First_SF_Id .. Last_Argument_Source loop
            if Source_Info (SF) /= Ignore_Unit then
               Put_Line (Source_List_File, Short_Source_Name (SF));
            end if;
         end loop;

         Close (Source_List_File);

         if Tool_Args.Text_Report_Enabled then
            Report (Auxiliary_List_File_Name (Source_List_File_Name_Str));
         end if;
      end;

      if Tool_Args.Text_Report_Enabled then
         Report_EOL;
      end if;

      if Tool_Args.XML_Report_Enabled then
         for SF in First_SF_Id .. Last_Argument_Source loop
            if Tool_Args.XML_Report_Enabled
              and then Source_Info (SF) /= Ignore_Unit
            then
               XML_Report
                 ("<source>" & Source_Name (SF) & "</source>",
                  Indent_Level => 2);
            end if;
         end loop;

         XML_Report ("</sources>", Indent_Level => 1);
      end if;
   end Print_File_List_File;

   ------------------------
   -- Print_Command_Line --
   ------------------------

   procedure Print_Command_Line (XML : Boolean := False) is
   begin
      if XML then
         XML_Report_No_EOL (Ada.Command_Line.Command_Name);

         for Arg in 1 .. Ada.Command_Line.Argument_Count loop
            XML_Report_No_EOL (" " & Ada.Command_Line.Argument (Arg));
         end loop;
      else
         Report_No_EOL (Ada.Command_Line.Command_Name);

         for Arg in 1 .. Ada.Command_Line.Argument_Count loop
            Report_No_EOL (" " & Ada.Command_Line.Argument (Arg));
         end loop;

         Report_EOL;
      end if;
   end Print_Command_Line;

   ----------------------------------
   -- Print_Ignored_File_List_File --
   ----------------------------------

   procedure Print_Ignored_File_List_File is
      Ignored_Source_List_File : Ada.Text_IO.File_Type;
   begin
      if Ignored_Sources = 0 then
         return;
      end if;

      if Tool_Args.Text_Report_Enabled then
         Report_No_EOL ("list of ignored sources   : ");
      end if;

      if Tool_Args.XML_Report_Enabled then
         XML_Report_No_EOL
           ("<ignored-sources from-file=""", Indent_Level => 1);
      end if;

      declare
         Full_Ignored_Source_List_File_Name : constant String :=
           (if Tool_Args.Text_Report_File_Path /= ""
            then Containing_Directory (Tool_Args.Text_Report_File_Path)
            else Containing_Directory (Tool_Args.XML_Report_File_Path))
           & GNAT.OS_Lib.Directory_Separator
           & Auxiliary_List_File_Name (Ignored_Source_List_File_Name_Str);

      begin
         if Tool_Args.XML_Report_Enabled then
            XML_Report
              (Auxiliary_List_File_Name (Ignored_Source_List_File_Name_Str)
               & """>");
         end if;

         if GNAT.OS_Lib.Is_Regular_File (Full_Ignored_Source_List_File_Name)
         then
            Open
              (Ignored_Source_List_File,
               Out_File,
               Full_Ignored_Source_List_File_Name);
         else
            Create
              (Ignored_Source_List_File,
               Out_File,
               Full_Ignored_Source_List_File_Name);
         end if;

         for SF in First_SF_Id .. Last_Argument_Source loop
            if Source_Info (SF) = Ignore_Unit then
               Put_Line (Ignored_Source_List_File, Short_Source_Name (SF));
            end if;
         end loop;

         Close (Ignored_Source_List_File);

         if Tool_Args.Text_Report_Enabled then
            Report
              (Auxiliary_List_File_Name (Ignored_Source_List_File_Name_Str));
         end if;
      end;

      if Tool_Args.Text_Report_Enabled then
         Report_EOL;
      end if;

      if Tool_Args.XML_Report_Enabled then
         for SF in First_SF_Id .. Last_Argument_Source loop
            if Tool_Args.XML_Report_Enabled
              and then Source_Info (SF) = Ignore_Unit
            then
               XML_Report
                 ("<source>" & Source_Name (SF) & "</source>",
                  Indent_Level => 2);
            end if;
         end loop;

         XML_Report ("</ignored-sources>", Indent_Level => 1);
      end if;
   end Print_Ignored_File_List_File;

   ---------------------------
   -- Print_Out_Diagnostics --
   ---------------------------

   procedure Print_Out_Diagnostics (Collector : in out Diagnostic_Collector) is
      Max_Diagnostics      : constant Natural :=
        (if Mode = Gnatkp_Mode then 0 else Tool_Args.Max_Diagnostics.Get);
      Diagnostics_Reported : Natural := 0;
      Limit_Exceeded       : Boolean := False;

      procedure Print_Diagnostic (Position : Error_Messages_Storage.Cursor);
      --  Print the diagnostic at the given position

      procedure Count_And_Print_Diagnostic
        (Position : Error_Messages_Storage.Cursor);
      --  Check whether the number of printed diagnostics is exceeding the
      --  limit, then print either a warning message or the diagnostic itself.

      procedure Print_Diagnostic (Position : Error_Messages_Storage.Cursor) is
      begin
         if Error_Messages_Storage.Element (Position).Justification
           = Null_Unbounded_String
         then
            Diagnostics_Reported := @ + 1;
            Print
              (Strip_Tag (Image (Error_Messages_Storage.Element (Position))));
         end if;
      end Print_Diagnostic;

      procedure Count_And_Print_Diagnostic
        (Position : Error_Messages_Storage.Cursor) is
      begin
         if not Limit_Exceeded then
            if Diagnostics_Reported >= Max_Diagnostics then
               Limit_Exceeded := True;
               Info
                 ("maximum diagnostics reached, see the report file for full "
                  & "details");
            else
               Print_Diagnostic (Position);
            end if;
         end if;
      end Count_And_Print_Diagnostic;

   begin
      Collector.All_Error_Messages.Iterate
        ((if Max_Diagnostics > 0
          then Count_And_Print_Diagnostic'Access
          else Print_Diagnostic'Access));
   end Print_Out_Diagnostics;

   -------------------------
   -- Print_Report_Header --
   -------------------------

   procedure Print_Report_Header is
      Time_Of_Check  : constant Time := Clock;
      Month_Of_Check : constant Month_Number := Month (Time_Of_Check);
      Day_Of_Check   : constant Day_Number := Day (Time_Of_Check);
      Sec_Of_Check   : constant Day_Duration := Seconds (Time_Of_Check);

      Sec_Of_Day      : Integer := Integer (Sec_Of_Check);
      Hour_Of_Check   : Integer range 0 .. 23;
      Minute_Of_Check : Integer range 0 .. 59;
      Seconds_In_Hour : constant Integer := 60 * 60;

   begin
      if Sec_Of_Day = 86400 then
         --  This happens when Sec_Of_Check is very close to the end of the
         --  day (it is in 86399.5 .. 86400.0). We treat this situation as the
         --  last second of this day - 23:59:59, but not as the first second
         --  of the next day - 00:00:00, so
         Sec_Of_Day := @ - 1;
      end if;

      Hour_Of_Check := Sec_Of_Day / Seconds_In_Hour;
      Minute_Of_Check := (Sec_Of_Day rem Seconds_In_Hour) / 60;

      if Tool_Args.Text_Report_Enabled then
         Report ("GNATCheck report");
         Report_EOL;

         Report_No_EOL ("date              : ");
         Report_No_EOL (Trim (Year (Time_Of_Check)'Img, Left) & '-');

         if Month_Of_Check < 10 then
            Report_No_EOL ("0");
         end if;

         Report_No_EOL (Trim (Month_Of_Check'Img, Left) & '-');

         if Day_Of_Check < 10 then
            Report_No_EOL ("0");
         end if;

         Report_No_EOL (Trim (Day_Of_Check'Img, Left) & ' ');

         if Hour_Of_Check < 10 then
            Report_No_EOL ("0");
         end if;

         Report_No_EOL (Trim (Hour_Of_Check'Img, Left) & ':');

         if Minute_Of_Check < 10 then
            Report_No_EOL ("0");
         end if;

         Report (Trim (Minute_Of_Check'Img, Left));

         Report (Lkql_Checker_Mode_Image & " version : " & Version_String);

         Report_No_EOL ("command line      : ");
         Print_Command_Line;

         Report_No_EOL ("runtime           : ");
         Print_Runtime;
      end if;

      if Tool_Args.XML_Report_Enabled then
         XML_Report_No_EOL
           ("<date>" & Trim (Year (Time_Of_Check)'Img, Left) & '-',
            Indent_Level => 1);
         XML_Report_No_EOL (if Month_Of_Check < 10 then "0" else "");
         XML_Report_No_EOL (Trim (Month_Of_Check'Img, Left) & '-');
         XML_Report_No_EOL (if Day_Of_Check < 10 then "0" else "");
         XML_Report_No_EOL (Trim (Day_Of_Check'Img, Left) & ' ');
         XML_Report_No_EOL (if Hour_Of_Check < 10 then "0" else "");
         XML_Report_No_EOL (Trim (Hour_Of_Check'Img, Left) & ':');
         XML_Report_No_EOL (if Minute_Of_Check < 10 then "0" else "");
         XML_Report (Trim (Minute_Of_Check'Img, Left) & "</date>");

         XML_Report
           ("<version>gnatcheck " & Version_String & "</version>",
            Indent_Level => 1);

         XML_Report_No_EOL ("<command-line>", Indent_Level => 1);
         Print_Command_Line (XML => True);
         XML_Report ("</command-line>");

         XML_Report_No_EOL ("<runtime>", Indent_Level => 1);
         Print_Runtime (XML => True);
         XML_Report ("</runtime>");
      end if;
   end Print_Report_Header;

   -------------------
   -- Print_Runtime --
   -------------------

   procedure Print_Runtime (XML : Boolean := False) is
   begin
      if Checker_Prj.Ada_Runtime /= "" then
         if XML then
            XML_Report (Checker_Prj.Ada_Runtime);
         else
            Report (Checker_Prj.Ada_Runtime);
         end if;
      else
         if XML then
            XML_Report_No_EOL ("default");
         else
            Report ("<default>");
         end if;
      end if;
   end Print_Runtime;

   -----------------------------
   -- Print_Violation_Summary --
   -----------------------------

   procedure Print_Violation_Summary is
   begin
      if Tool_Args.Text_Report_Enabled then
         Report
           ("non-exempted violations               :"
            & Detected_Non_Exempted_Violations'Img,
            1);
         Report
           ("rule exemption warnings               :"
            & Detected_Exemption_Warning'Img,
            1);
         Report
           ("compilation errors                    :"
            & Detected_Compiler_Error'Img,
            1);
         Report
           ("exempted violations                   :"
            & Detected_Exempted_Violations'Img,
            1);
         Report
           ("internal errors                       :"
            & Detected_Internal_Error'Img,
            1);
      end if;

      if Tool_Args.XML_Report_Enabled then
         XML_Report
           ("<non-exempted-violations>"
            & Image (Detected_Non_Exempted_Violations)
            & "</non-exempted-violations>",
            Indent_Level => 1);
         XML_Report
           ("<rule-exemption-warnings>"
            & Image (Detected_Exemption_Warning)
            & "</rule-exemption-warnings>",
            Indent_Level => 1);
         XML_Report
           ("<compilation-errors>"
            & Image (Detected_Compiler_Error)
            & "</compilation-errors>",
            Indent_Level => 1);
         XML_Report
           ("<exempted-violations>"
            & Image (Detected_Exempted_Violations)
            & "</exempted-violations>",
            Indent_Level => 1);
         XML_Report
           ("<gnatcheck-errors>"
            & Image (Detected_Internal_Error)
            & "</gnatcheck-errors>",
            Indent_Level => 1);
         XML_Report ("</summary>");
      end if;
   end Print_Violation_Summary;

   ---------------------------
   -- Process_User_Filename --
   ---------------------------

   procedure Process_User_Filename (Fname : String) is
   begin
      if GNAT.OS_Lib.Is_Regular_File (Fname) then
         User_Info_File := new String'(Fname);
         User_Info_File_Full_Path :=
           new String'
             (GNAT.OS_Lib.Normalize_Pathname (Fname, Resolve_Links => False));
      else
         Error (Fname & " not found, --include-file option ignored");
      end if;
   end Process_User_Filename;

   ----------------
   -- Sloc_Image --
   ----------------

   function Sloc_Image (Line, Column : Natural) return String is
      Line_Image : constant String := Line'Image;
      Col_Image  : constant String := Column'Image;
   begin
      if Column < 10 then
         return
           Line_Image (2 .. Line_Image'Last)
           & ":0"
           & Col_Image (2 .. Col_Image'Last);
      else
         return
           Line_Image (2 .. Line_Image'Last)
           & ":"
           & Col_Image (2 .. Col_Image'Last);
      end if;
   end Sloc_Image;

   function Sloc_Image (Sloc : Source_Location) return String is
   begin
      return Sloc_Image (Natural (Sloc.Line), Natural (Sloc.Column));
   end Sloc_Image;

   ----------------------
   -- Store_Diagnostic --
   ----------------------

   procedure Store_Diagnostic
     (Collector : in out Diagnostic_Collector;
      Text      : String;
      Kind      : Diagnostic_Kind;
      SF        : SF_Id;
      Rule      : Rule_Id := No_Rule_Id;
      Instance  : Rule_Instance_Access := null)
   is
      Matches : Match_Array (0 .. 5);
      Sloc    : Source_Location;
   begin
      Match (Match_Diagnostic, Text, Matches);

      pragma
        Assert
          (Matches (0) /= No_Match, "Invalid text for diagnostic: " & Text);

      Sloc.Line :=
        Line_Number'Value (Text (Matches (3).First .. Matches (3).Last));
      Sloc.Column :=
        Column_Number'Value (Text (Matches (4).First .. Matches (4).Last));

      Store_Diagnostic
        (Collector,
         Full_File_Name => Text (Matches (1).First .. Matches (1).Last),
         Sloc           => Sloc,
         Message        => Text (Matches (5).First .. Matches (5).Last),
         Kind           => Kind,
         SF             => SF,
         Rule           => Rule,
         Instance       => Instance);
   end Store_Diagnostic;

   procedure Store_Diagnostic
     (Collector      : in out Diagnostic_Collector;
      Full_File_Name : String;
      Message        : String;
      Sloc           : Source_Location;
      Kind           : Diagnostic_Kind;
      SF             : SF_Id;
      Rule           : Rule_Id := No_Rule_Id;
      Instance       : Rule_Instance_Access := null)
   is
      File_Name : constant Unbounded_String :=
        To_Unbounded_String
          (if Tool_Args.Full_Source_Locations.Get
           then Full_File_Name
           else Simple_Name (Full_File_Name));
      Tmp       : Diagnostic :=
        (Text          => To_Unbounded_String (Message),
         Sloc          => Sloc,
         File          => File_Name,
         Justification => Null_Unbounded_String,
         Kind          => Kind,
         Rule          => Rule,
         Instance      => Instance,
         SF            => SF);
   begin
      --  We need this check to avoid diagnostics duplication. Our set
      --  container has broken "<" relation, so Insert may add diagnostics
      --  that are already stored in the container (see the documentation for
      --  "<" for more
      --  details.
      if not Collector.All_Error_Messages.Contains (Tmp) then
         if Kind = Compiler_Error then
            Set_Source_Status (SF, Not_A_Legal_Source);
         elsif Kind = Internal_Error then
            Set_Source_Status (SF, Error_Detected);
         end if;
         Collector.All_Error_Messages.Insert (Tmp);
      end if;
   end Store_Diagnostic;

   ---------------
   -- Strip_Tag --
   ---------------

   function Strip_Tag (Diag : String) return String is
      Idx : constant Natural := Index (Diag, " [-gnat");
   begin
      return (if Idx = 0 then Diag else Diag (Diag'First .. Idx - 1));
   end Strip_Tag;

   ---------------------------
   -- XML_Report_Diagnostic --
   ---------------------------

   procedure XML_Report_Diagnostic (Diag : Diagnostic; Short_Report : Boolean)
   is
      Indentation : constant Natural := (if Short_Report then 1 else 2);
      Exempted    : constant Boolean :=
        Diag.Kind = Rule_Violation
        and then Diag.Justification /= Null_Unbounded_String;
      Message     : constant String := Strip_Tag (To_String (Diag.Text));
      M_Start     : Natural := Message'First;
   begin
      XML_Report_No_EOL
        ((if Diag.Kind = Exemption_Warning
          then "<exemption-problem"
          elsif Diag.Kind = Compiler_Error
          then "<compiler-error"
          elsif Diag.Kind = Internal_Error
          then "<internal-error"
          elsif Exempted
          then "<exempted-violation"
          else "<violation"),
         Indent_Level => Indentation);

      XML_Report_No_EOL
        (" file=""" & Escape_XML (To_String (Diag.File)) & """ ");

      XML_Report_No_EOL
        ("line="""
         & Ada.Strings.Fixed.Trim (Line_Number'Image (Diag.Sloc.Line), Left)
         & """ ");

      XML_Report_No_EOL
        ("column="""
         & Ada.Strings.Fixed.Trim
             (Column_Number'Image (Diag.Sloc.Column), Left)
         & """");

      if Diag.Kind = Rule_Violation then
         XML_Report_No_EOL (" rule-id=""" & Rule_Name (Diag.Rule) & '"');
      end if;

      XML_Report (">");

      --  Strip the "error: " tag from the diagnostic message if it is a
      --  compiler error.
      if Diag.Kind = Compiler_Error then
         M_Start := Index (Message, "error: ");
         if M_Start = 0 then
            M_Start := Message'First;
         else
            M_Start := @ + 7;
         end if;
      end if;

      XML_Report
        ("<message>"
         & Escape_XML (Message (M_Start .. Message'Last))
         & "</message>",
         Indent_Level => Indentation + 1);

      if Exempted then
         XML_Report
           ("<justification>"
            & Escape_XML (To_String (Diag.Justification))
            & "</justification>",
            Indent_Level => Indentation + 1);
      end if;

      XML_Report
        ((if Diag.Kind = Exemption_Warning
          then "</exemption-problem>"
          elsif Diag.Kind = Compiler_Error
          then "</compiler-error>"
          elsif Diag.Kind = Internal_Error
          then "</internal-error>"
          elsif Exempted
          then "</exempted-violation>"
          else "</violation>"),
         Indent_Level => Indentation);
   end XML_Report_Diagnostic;

   -----------
   -- Image --
   -----------

   function Image (Self : Diagnostic) return String is
      function Image (Sloc : Source_Location) return String;
      --  Custom image function for Langkit source locations, that will add a
      --  leading 0 for columns under 10.

      -----------
      -- Image --
      -----------

      function Image (Sloc : Source_Location) return String is
         Column_Str : constant String :=
           (if Sloc.Column >= 10 then "" else "0")
           & Ada.Strings.Fixed.Trim (Column_Number'Image (Sloc.Column), Left);
      begin
         return
           (Ada.Strings.Fixed.Trim (Line_Number'Image (Sloc.Line), Left)
            & ':'
            & Column_Str);
      end Image;

      Tag_String : constant String :=
        (case Self.Kind is
           when Rule_Violation    =>
             (if Self.Justification /= Null_Unbounded_String
              then "rule violation (exempted): "
              else "rule violation: "),
           when Exemption_Warning => "warning: ",
           when others            => "");
   begin
      return
        To_String (Self.File)
        & ":"
        & Image (Self.Sloc)
        & ": "
        & Tag_String
        & To_String (Self.Text);
   end Image;

end Lkql_Checker.Diagnostics;
