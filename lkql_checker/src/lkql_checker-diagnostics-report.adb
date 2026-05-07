--
--  Copyright (C) 2005-2026, AdaCore
--  SPDX-License-Identifier: GPL-3.0-or-later
--

with Ada.Characters.Handling;   use Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Directories;           use Ada.Directories;
with Ada.Environment_Variables; use Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings;               use Ada.Strings;
with Ada.Strings.Fixed;         use Ada.Strings.Fixed;
with Ada.Strings.Unbounded;     use Ada.Strings.Unbounded;
with Ada.Text_IO;               use Ada.Text_IO;

with GNAT.Calendar.Time_IO; use GNAT.Calendar.Time_IO;
with GNAT.OS_Lib;           use GNAT.OS_Lib;

with GNATCOLL.VFS; use GNATCOLL.VFS;

with Lkql_Checker.Compiler;               use Lkql_Checker.Compiler;
with Lkql_Checker.Diagnostics.Exemptions;
use Lkql_Checker.Diagnostics.Exemptions;
with Lkql_Checker.Options;                use Lkql_Checker.Options;
with Lkql_Checker.Output;                 use Lkql_Checker.Output;
with Lkql_Checker.Rules;                  use Lkql_Checker.Rules;
with Lkql_Checker.Rules.Rule_Table;       use Lkql_Checker.Rules.Rule_Table;
with Lkql_Checker.Source_Table;           use Lkql_Checker.Source_Table;
with Lkql_Checker.String_Utilities;       use Lkql_Checker.String_Utilities;

with Rule_Commands;

with SARIF.Types;
with SARIF.Types.Outputs;

with VSS.JSON.Push_Writers;
with VSS.JSON.Streams;
with VSS.Stream_Element_Vectors.Conversions;
with VSS.Strings.Conversions;
with VSS.Text_Streams.Memory_UTF8_Output;

package body Lkql_Checker.Diagnostics.Report is

   --  Rename Lkql_Checker.Output.Report to avoid name collision with this
   --  package.
   procedure Text_Report (Message : String; Indent_Level : Natural := 0)
   renames Lkql_Checker.Output.Report;

   ------------------------------------------
   -- Local routines for report generation --
   ------------------------------------------

   Rule_List_File_Name_Str           : constant String := "-rule-list";
   Source_List_File_Name_Str         : constant String := "-source-list";
   Ignored_Source_List_File_Name_Str : constant String :=
     "-ignored-source-list";

   function Auxiliary_List_File_Name (S : String) return String;
   --  Should be used for getting the names of auxiliary files needed
   --  for GNATcheck report (list of processed sources, list of applied
   --  rules, list of ignored sources). Parameter specifies a substring
   --  to be included into the report file name to get the name of the
   --  auxiliary file.

   procedure Copy_User_Info;
   --  Copies into the report file the text from user-provided file.

   function Escape_XML (S : String) return String;
   --  Escape relevant characters from S by their corresponding XML
   --  symbols

   procedure Print_Active_Rules_File;
   --  Prints the reference to the (actual argument or artificially
   --  created) file that contains the list of all the rules that are
   --  active for the given checker run.

   procedure Print_Argument_Files_Summary
     (Checked_Sources                  : Natural;
      Unverified_Sources               : Natural;
      Fully_Compliant_Sources          : Natural;
      Sources_With_Violations          : Natural;
      Sources_With_Exempted_Violations : Natural;
      Ignored_Sources                  : Natural);
   --  Prints the total numbers of: all the argument files,
   --  non-compilable files, files with no violations, files with
   --  violations, files with exempted violations only.

   type Diagnostic_Kind_Filter is array (Diagnostic_Kind) of Boolean;
   --  An array type used to filter diagnostics following their kind.

   procedure Print_Diagnostics
     (Collector                      : in out Diagnostic_Collector;
      Filter                         : Diagnostic_Kind_Filter;
      Print_Only_Exempted_Violations : Boolean := False);
   --  Iterates through all the diagnostics and prints into the report
   --  file those of them for which match the provided filter.
   --  Print_Only_Exempted_Violations controls whether exempted or
   --  non-exempted rule violations are printed.

   procedure Print_File_List_File;
   --  Prints the reference to the (actual argument or artificially
   --  created) file that contains the list of all the files passed to
   --  the checker.

   procedure Print_Ignored_File_List_File (Ignored_Sources : Natural);
   --  Prints the reference to the artificially created file that
   --  contains the list of files passed to the checker that have not
   --  been processed because '--ignore=...' option. Note that it can
   --  be different from the list provided by '--ignore=...' option -
   --  this list contains only the existing files that have been passed
   --  as tool argument sources.

   function Get_Command_Line return String;
   --  Get the command line that has been used to spawn the process.

   procedure Print_Command_Line (XML : Boolean := False);
   --  Prints the command line used to run this Lkql_Checker instance.
   --  In case it has been called from the GNAT driver, prints the call
   --  to the GNAT driver, but not the call generated by the GNAT
   --  driver. If XML is ON, prints the output into XML output file,
   --  otherwise in the text output file.

   procedure Print_Out_Diagnostics (Collector : in out Diagnostic_Collector);
   --  Duplicates diagnostics about non-exempted rule violations,
   --  exemption warnings and compiler error messages into stderr. Up
   --  to value specified with the ``-m`` CLI option diagnostics are
   --  reported. If this value equal to 0, all the diagnostics of
   --  these kinds are reported.

   procedure Print_Runtime (XML : Boolean := False);
   --  Prints the runtime version used for the checker call. It is
   --  either the parameter of --RTS option used for the (actual)
   --  checker call or the "<default>" string if --RTS parameter is
   --  not specified. If XML is ON, prints the output into XML output
   --  file, otherwise - in the text output file.

   procedure Print_Violation_Summary;
   --  Prints the total numbers of: non-exempted violations, exempted
   --  violations, exemption warnings and compiler errors.

   procedure XML_Report_Diagnostic (Diag : Diagnostic; Short_Report : Boolean);
   --  Prints into XML report file the information from the diagnostic.
   --  The boolean parameter is used to define the needed indentation
   --  level.

   function Strip_Tag (Diag : String) return String;
   --  Strip trailing GNAT tag following the format " [-gnat<x>]", if
   --  any

   function Image (Self : Diagnostic) return String;
   --  Returns a text image of a diagnostic for text report output

   type Statistics is record
      Checked_Sources                  : Natural := 0;
      Unverified_Sources               : Natural := 0;
      Fully_Compliant_Sources          : Natural := 0;
      Sources_With_Violations          : Natural := 0;
      Sources_With_Exempted_Violations : Natural := 0;
      Ignored_Sources                  : Natural := 0;
   end record;

   function Compute_Statistics
     (Collector : in out Diagnostic_Collector) return Statistics;
   --  Computes the number of violations and diagnostics of different
   --  kinds. Results are stored in the corresponding counters in the
   --  package spec. Also computes and returns file statistics.

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
         --  in case of aggregated project we have to move the index
         --  in the Prj_Out_File after S. That is, we do not need
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

   function Compute_Statistics
     (Collector : in out Diagnostic_Collector) return Statistics
   is
      Stats : Statistics;

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
            Stats.Unverified_Sources := @ + 1;
         else
            Stats.Checked_Sources := @ + 1;

            if File_Counter (SF).Non_Exempted_Violations_Detected then
               Stats.Sources_With_Violations := @ + 1;
            elsif File_Counter (SF).Exempted_Violations_Detected then
               Stats.Sources_With_Exempted_Violations := @ + 1;
            elsif Source_Status (SF) = Processed then
               Stats.Fully_Compliant_Sources := @ + 1;
            end if;
         end if;
      end loop;

      Stats.Ignored_Sources := Exempted_Sources;

      return Stats;
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
      Open
        (File => User_File,
         Mode => In_File,
         Name => User_Info_File_Full_Path.all);

      loop
         exit when End_Of_File (User_File);

         Get_Line (File => User_File, Item => Line_Buf, Last => Line_Len);

         if Tool_Args.Text_Report_Enabled then
            Text_Report (Line_Buf (1 .. Line_Len));
         end if;

         if Tool_Args.XML_Report_Enabled then
            XML_Report (Line_Buf (1 .. Line_Len), 1);
         end if;
      end loop;

      Close (User_File);
   exception
      when E : others =>

         Report_EOL;
         Text_Report
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

   -----------------------------------
   -- Generate_Qualification_Report --
   -----------------------------------

   procedure Generate_Qualification_Report
     (Collector : in out Diagnostic_Collector)
   is
      Stats : Statistics;
   begin
      Process_Postponed_Exemptions (Collector);
      Stats := Compute_Statistics (Collector);

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
         Print_Ignored_File_List_File (Stats.Ignored_Sources);
         Print_Argument_Files_Summary
           (Stats.Checked_Sources,
            Stats.Unverified_Sources,
            Stats.Fully_Compliant_Sources,
            Stats.Sources_With_Violations,
            Stats.Sources_With_Exempted_Violations,
            Stats.Ignored_Sources);

         if Tool_Args.Text_Report_Enabled then
            Report_EOL;
         end if;

         Print_Violation_Summary;

         --  2. DETECTED EXEMPTED RULE VIOLATIONS
         if Tool_Args.Text_Report_Enabled then
            Report_EOL;
            Text_Report ("2. Exempted Coding Standard Violations");
            Report_EOL;
         end if;

         if Tool_Args.XML_Report_Enabled then
            XML_Report ("<violations>");
         end if;
      end if;

      if Detected_Exempted_Violations > 0 then
         Print_Diagnostics
           (Collector,
            Filter                         =>
              [Rule_Violation    => True,
               Exemption_Warning => False,
               Compiler_Error    => False,
               Internal_Error    => False],
            Print_Only_Exempted_Violations => True);

      else
         if Tool_Args.Text_Report_Enabled then
            Text_Report ("no exempted violations detected", 1);
         end if;

         if not Tool_Args.Short_Report and then Tool_Args.XML_Report_Enabled
         then
            XML_Report ("no exempted violations detected", 1);
         end if;
      end if;

      if not Tool_Args.Short_Report then
         if Tool_Args.Text_Report_Enabled then
            Report_EOL;
            Text_Report ("3. Non-exempted Coding Standard Violations");
            Report_EOL;
         end if;
      end if;

      if Detected_Non_Exempted_Violations > 0 then
         Print_Diagnostics
           (Collector,
            Filter =>
              [Rule_Violation    => True,
               Exemption_Warning => False,
               Compiler_Error    => False,
               Internal_Error    => False]);

      else
         if Tool_Args.Text_Report_Enabled then
            Text_Report ("no non-exempted violations detected", 1);
         end if;

         if not Tool_Args.Short_Report and then Tool_Args.XML_Report_Enabled
         then
            XML_Report ("no non-exempted violations detected", 1);
         end if;
      end if;

      if not Tool_Args.Short_Report then
         if Tool_Args.Text_Report_Enabled then
            Report_EOL;
            Text_Report ("4. Rule exemption problems");
            Report_EOL;
         end if;
      end if;

      if Detected_Exemption_Warning > 0 then
         Print_Diagnostics
           (Collector,
            Filter =>
              [Rule_Violation    => False,
               Exemption_Warning => True,
               Compiler_Error    => False,
               Internal_Error    => False]);

      else
         if Tool_Args.Text_Report_Enabled then
            Text_Report ("no rule exemption problems detected", 1);
         end if;

         if not Tool_Args.Short_Report and then Tool_Args.XML_Report_Enabled
         then
            XML_Report ("no rule exemption problems detected", 1);
         end if;

      end if;

      if not Tool_Args.Short_Report then
         if Tool_Args.Text_Report_Enabled then
            Report_EOL;
            Text_Report ("5. Language violations");
            Report_EOL;
         end if;
      end if;

      if Detected_Compiler_Error > 0 then
         Print_Diagnostics
           (Collector,
            Filter =>
              [Rule_Violation    => False,
               Exemption_Warning => False,
               Compiler_Error    => True,
               Internal_Error    => False]);

      else
         if Tool_Args.Text_Report_Enabled then
            Text_Report ("no language violations detected", 1);
         end if;

         if not Tool_Args.Short_Report and then Tool_Args.XML_Report_Enabled
         then
            XML_Report ("no language violations detected", 1);
         end if;
      end if;

      if not Tool_Args.Short_Report then
         if Tool_Args.Text_Report_Enabled then
            Report_EOL;
            Text_Report ("6. Gnatcheck internal errors");
            Report_EOL;
         end if;
      end if;

      if Detected_Internal_Error > 0 then
         Print_Diagnostics
           (Collector,
            Filter =>
              [Rule_Violation    => False,
               Exemption_Warning => False,
               Compiler_Error    => False,
               Internal_Error    => True]);

      else
         if Tool_Args.Text_Report_Enabled then
            Text_Report ("no internal error detected", 1);
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
               Text_Report ("7. Additional Information");
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

   -----------
   -- Image --
   -----------

   function Image (Self : Diagnostic) return String is
      function Image (Sloc : Source_Location) return String;
      --  Custom image function for Langkit source locations, that
      --  will add a leading 0 for columns under 10.

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
            Text_Report (To_String (Legacy_Rule_File_Name));
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
              & Directory_Separator
              & Auxiliary_List_File_Name (Rule_List_File_Name_Str);

         begin
            if Is_Regular_File (Full_Rule_List_File_Name) then
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
               Text_Report
                 (Auxiliary_List_File_Name (Rule_List_File_Name_Str));
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
            XML_Print_Active_Restrictions (2);
         end if;

         XML_Report ("</coding-standard>", Indent_Level => 1);
      end if;
   end Print_Active_Rules_File;

   ----------------------------------
   -- Print_Argument_Files_Summary --
   ----------------------------------

   procedure Print_Argument_Files_Summary
     (Checked_Sources                  : Natural;
      Unverified_Sources               : Natural;
      Fully_Compliant_Sources          : Natural;
      Sources_With_Violations          : Natural;
      Sources_With_Exempted_Violations : Natural;
      Ignored_Sources                  : Natural) is
   begin

      if Tool_Args.Text_Report_Enabled then
         Text_Report ("1. Summary");
         Report_EOL;

         Text_Report
           ("fully compliant sources               :"
            & Fully_Compliant_Sources'Img,
            1);
         Text_Report
           ("sources with exempted violations only :"
            & Sources_With_Exempted_Violations'Img,
            1);
         Text_Report
           ("sources with non-exempted violations  :"
            & Sources_With_Violations'Img,
            1);
         Text_Report
           ("unverified sources                    :" & Unverified_Sources'Img,
            1);
         Text_Report
           ("total sources                         :"
            & Last_Argument_Source'Img,
            1);
         Text_Report
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

   ----------------------
   -- Get_Command_Line --
   ----------------------

   function Get_Command_Line return String is
      Res : Unbounded_String :=
        To_Unbounded_String (Ada.Command_Line.Command_Name);
   begin
      for Arg in 1 .. Ada.Command_Line.Argument_Count loop
         Append (Res, " " & Ada.Command_Line.Argument (Arg));
      end loop;
      return To_String (Res);
   end Get_Command_Line;

   ------------------------
   -- Print_Command_Line --
   ------------------------

   procedure Print_Command_Line (XML : Boolean := False) is
   begin
      if XML then
         XML_Report_No_EOL (Get_Command_Line);
      else
         Text_Report (Get_Command_Line);
      end if;
   end Print_Command_Line;

   -----------------------
   -- Print_Diagnostics --
   -----------------------

   procedure Print_Diagnostics
     (Collector                      : in out Diagnostic_Collector;
      Filter                         : Diagnostic_Kind_Filter;
      Print_Only_Exempted_Violations : Boolean := False)
   is

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
         if Filter (Diag.Kind) then
            if Diag.Kind = Rule_Violation
              and then Print_Only_Exempted_Violations
                       = (Diag.Justification = Null_Unbounded_String)
            then
               return;
            end if;

            if Tool_Args.Text_Report_Enabled then
               Text_Report (Strip_Tag (Image (Diag)));

               if Diag.Justification /= Null_Unbounded_String then
                  Text_Report ("(" & To_String (Diag.Justification) & ")", 1);
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
           & Directory_Separator
           & Auxiliary_List_File_Name (Source_List_File_Name_Str);

      begin
         if Tool_Args.XML_Report_Enabled then
            XML_Report
              (Auxiliary_List_File_Name (Source_List_File_Name_Str) & """>");
         end if;

         if Is_Regular_File (Full_Source_List_File_Name) then
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
            Text_Report (Auxiliary_List_File_Name (Source_List_File_Name_Str));
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

   ----------------------------------
   -- Print_Ignored_File_List_File --
   ----------------------------------

   procedure Print_Ignored_File_List_File (Ignored_Sources : Natural) is
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
           & Directory_Separator
           & Auxiliary_List_File_Name (Ignored_Source_List_File_Name_Str);

      begin
         if Tool_Args.XML_Report_Enabled then
            XML_Report
              (Auxiliary_List_File_Name (Ignored_Source_List_File_Name_Str)
               & """>");
         end if;

         if Is_Regular_File (Full_Ignored_Source_List_File_Name) then
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
            Text_Report
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
      Max_Diagnostics : constant Natural :=
        (if Mode = Gnatkp_Mode then 0 else Tool_Args.Max_Diagnostics.Get);
      Count           : Natural := 0;
      Warning_Emitted : Boolean := False;

      procedure Print_One_Diagnostic
        (Position : Error_Messages_Storage.Cursor);

      procedure Print_One_Diagnostic (Position : Error_Messages_Storage.Cursor)
      is
         Diag : constant Diagnostic :=
           Error_Messages_Storage.Element (Position);
      begin
         --  Check if the diagnostic is exempted
         if Diag.Justification /= Null_Unbounded_String then
            return;
         end if;

         --  Then check if the diagnostic limit has been reached
         if Max_Diagnostics /= 0 and then Count >= Max_Diagnostics then
            if not Warning_Emitted then
               Info
                 ("maximum diagnostics reached, see the report file for full "
                  & "details");
               Warning_Emitted := True;
            end if;
            return;
         end if;

         --  Finally print the diagnostic
         Print (Strip_Tag (Image (Diag)));
         Count := Count + 1;
      end Print_One_Diagnostic;

   begin
      Collector.All_Error_Messages.Iterate (Print_One_Diagnostic'Access);
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
         --  This happens when Sec_Of_Check is very close to the end
         --  of the day (it is in 86399.5 .. 86400.0). We treat this
         --  situation as the last second of this day - 23:59:59, but
         --  not as the first second of the next day - 00:00:00, so
         Sec_Of_Day := @ - 1;
      end if;

      Hour_Of_Check := Sec_Of_Day / Seconds_In_Hour;
      Minute_Of_Check := (Sec_Of_Day rem Seconds_In_Hour) / 60;

      if Tool_Args.Text_Report_Enabled then
         Text_Report ("GNATCheck report");
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

         Text_Report (Trim (Minute_Of_Check'Img, Left));

         Text_Report
           (Lkql_Checker_Mode_Image & " version : " & Version_String);

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
            Text_Report (Checker_Prj.Ada_Runtime);
         end if;
      else
         if XML then
            XML_Report_No_EOL ("default");
         else
            Text_Report ("<default>");
         end if;
      end if;
   end Print_Runtime;

   -----------------------------
   -- Print_Violation_Summary --
   -----------------------------

   procedure Print_Violation_Summary is
   begin
      if Tool_Args.Text_Report_Enabled then
         Text_Report
           ("non-exempted violations               :"
            & Detected_Non_Exempted_Violations'Img,
            1);
         Text_Report
           ("rule exemption warnings               :"
            & Detected_Exemption_Warning'Img,
            1);
         Text_Report
           ("compilation errors                    :"
            & Detected_Compiler_Error'Img,
            1);
         Text_Report
           ("exempted violations                   :"
            & Detected_Exempted_Violations'Img,
            1);
         Text_Report
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
      if Is_Regular_File (Fname) then
         User_Info_File := new String'(Fname);
         User_Info_File_Full_Path :=
           new String'(Normalize_Pathname (Fname, Resolve_Links => False));
      else
         Error (Fname & " not found, --include-file option ignored");
      end if;
   end Process_User_Filename;

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

      --  Strip the "error: " tag from the diagnostic message if it
      --  is a compiler error.
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

   ---------------------------
   -- Generate_SARIF_Report --
   ---------------------------

   procedure Generate_SARIF_Report
     (Collector   : in out Diagnostic_Collector;
      Output_File : String;
      Start_Time  : Time;
      End_Time    : Time;
      Exit_Code   : Integer)
   is
      use VSS.Strings.Conversions;
      use VSS.JSON.Streams;

      package ST renames SARIF.Types;
      package SE renames SARIF.Types.Enum;

      --  Variables used to collect information
      Uri_Base_Dir         : constant Virtual_File :=
        Create_From_UTF8 (Checker_Prj.Get_Project_Dir);
      Uri_Base_Dir_Id      : constant String := "URI_BASE_DIR";
      Additional_Instances : Rule_Instance_Vector.Vector;

      Root       : ST.Root;
      Driver     : ST.toolComponent;
      Run        : ST.run;
      Invocation : ST.invocation;

      --  Variables require to emit the SARIF report
      Writer : VSS.JSON.Push_Writers.JSON_Simple_Push_Writer;
      Mem    :
        aliased VSS.Text_Streams.Memory_UTF8_Output.Memory_UTF8_Output_Stream;
      File   : File_Type;

      -------------------
      -- Local helpers --
      -------------------

      function To_Uri (File_Path : String) return String;
      --  Turn the provided file path into an URI.

      function To_Uri (File_Path : String) return String is
         File_Unix_Path : constant String :=
           String (Unix_Style_Full_Name (Create_From_UTF8 (File_Path)));
      begin
         return
           "file://"
           & (if Has_Prefix (File_Unix_Path, "/") then "" else "/")
           & File_Unix_Path;
      end To_Uri;

      function Make_Artifact_Location
        (File_Path : String; Relative_To_Base_Dir : Boolean := False)
         return ST.artifactLocation
      is (if Relative_To_Base_Dir
          then
            (uri       =>
               To_Virtual_String
                 (String
                    (Unix_Style_Full_Name
                       (Create
                          (Relative_Path
                             (Create_From_UTF8 (File_Path), Uri_Base_Dir))))),
             uriBaseId => To_Virtual_String (Uri_Base_Dir_Id),
             others    => <>)
          else (uri => To_Virtual_String (To_Uri (File_Path)), others => <>));
      --  Create an artifact location SARIF object from the provided file
      --  path. If ``Relative_To_Base_Dir`` is True, the returned artifact
      --  location is expressed relatively to the ``URI_BASE_DIR``.

      function Make_Location
        (File_Path : String; Line : Natural; Column : Natural)
         return ST.location;
      --  Build a SARIF location from a file path, a line and a column number.

      function Make_Location
        (File_Path : String; Line : Natural; Column : Natural)
         return ST.location
      is
         Loc  : ST.location;
         Phys : ST.physicalLocation;
         Reg  : ST.region;
      begin
         --  We start by describing the concerned file by its URI
         Phys.artifactLocation :=
           (Is_Set => True,
            Value  =>
              Make_Artifact_Location
                (File_Path, Relative_To_Base_Dir => True));

         --  Then we create a region from provided line and column
         Reg.startLine := (Is_Set => True, Value => Line);
         Reg.startColumn := (Is_Set => True, Value => Column);
         Phys.region := (Is_Set => True, Value => Reg);

         --  Finally, we construct the result object and we return it
         Loc.physicalLocation := (Is_Set => True, Value => Phys);
         return Loc;
      end Make_Location;

      function Make_Config
        (R_Id : Rule_Id; Instance : Rule_Instance_Access)
         return ST.reportingConfiguration;
      --  Build a SARIF rule configuration object from the provided rule and
      --  an instance of it. If the provided instance is null, the default one
      --  is used

      function Make_Config
        (R_Id : Rule_Id; Instance : Rule_Instance_Access)
         return ST.reportingConfiguration
      is
         Rule   : constant Rule_Info := All_Rules (R_Id);
         I      : Rule_Instance_Access;
         Args   : Rule_Commands.Rule_Argument_Vectors.Vector;
         Params : ST.propertyBag;
         Res    : ST.reportingConfiguration;
      begin
         --  If no instance has been provided, create the default one
         if Instance = null then
            I := Rule.Create_Instance (False);
            I.Source_Mode := General;
            I.Rule := R_Id;
         else
            I := Instance;
         end if;

         --  Fill the configuration SARIF object
         I.Map_Parameters (Args);
         for Arg of Args loop
            Params.Additional_Properties.Append
              ((Kind => Key_Name, Key_Name => To_Virtual_String (Arg.Name)));
            Params.Additional_Properties.Append
              ((Kind         => String_Value,
                String_Value => To_Virtual_String (Arg.Value)));
         end loop;
         Res.parameters := (Is_Set => True, Value => Params);
         Res.enabled := True;

         --  Free the default instance if one has been created
         if Instance = null then
            Free (I);
         end if;

         return Res;
      end Make_Config;

      procedure Add_Env_Var (Name, Value : String);
      --  Add an environment variable to the SARIF invocation object.

      procedure Add_Env_Var (Name, Value : String) is
      begin
         Invocation.environmentVariables.Append
           ((Kind => Key_Name, Key_Name => To_Virtual_String (Name)));
         Invocation.environmentVariables.Append
           ((Kind => String_Value, String_Value => To_Virtual_String (Value)));
      end Add_Env_Var;
   begin
      --  Set driver "constant" values
      Driver.name := To_Virtual_String (Lkql_Checker_Mode_Image);
      Driver.organization := To_Virtual_String ("AdaCore");
      Driver.informationUri :=
        To_Virtual_String
          ("https://docs.adacore.com/live/wave/lkql/html/gnatcheck_rm/"
           & "gnatcheck_rm.html");
      Driver.version := To_Virtual_String (Lkql_Checker_Version);

      --  Build the active rules list and collect additional instances
      for Cursor in All_Rules.Iterate loop
         declare
            R_Id             : constant Rule_Id := Rule_Map.Key (Cursor);
            Rule             : constant Rule_Info := Rule_Map.Element (Cursor);
            Default_Instance : Rule_Instance_Access := null;
            Descriptor       : ST.reportingDescriptor;
         begin
            if Is_Enabled (Rule) then
               for Instance of Rule.Instances loop
                  if Instance.Is_Alias then
                     Additional_Instances.Append (Instance);
                  else
                     Default_Instance := Instance;
                  end if;
               end loop;

               Descriptor.id := To_Virtual_String (Lower_Name (Rule));
               Descriptor.name := To_Virtual_String (Rule.Name);
               if Rule.Message /= Null_Unbounded_String
                 and then Rule.Message /= Rule.Name
               then
                  declare
                     Short_Desc : ST.multiformatMessageString;
                  begin
                     Short_Desc.text := To_Virtual_String (Rule.Message);
                     Descriptor.shortDescription :=
                       (Is_Set => True, Value => Short_Desc);
                  end;
               end if;
               if Rule.Help_Info /= Null_Unbounded_String
                 and then Rule.Help_Info /= Rule.Message
               then
                  declare
                     Help : ST.multiformatMessageString;
                  begin
                     Help.text := To_Virtual_String (Rule.Help_Info);
                     Descriptor.help := (Is_Set => True, Value => Help);
                  end;
               end if;
               Descriptor.defaultConfiguration :=
                 (Is_Set => True,
                  Value  => Make_Config (R_Id, Default_Instance));
               Driver.rules.Append (Descriptor);
            end if;
         end;
      end loop;

      --  Now add rule instances
      for Instance of Additional_Instances loop
         declare
            R_Id       : constant Rule_Id := Instance.Rule;
            Descriptor : ST.reportingDescriptor;
            Relation   : ST.reportingDescriptorRelationship;
         begin
            --  Relate the instance to its rule
            Relation.target :=
              (id => To_Virtual_String (Get_Id_Text (R_Id)), others => <>);

            --  Then add the instance as an active rule
            Descriptor.id :=
              To_Virtual_String (To_Lower (Instance.Instance_Name));
            Descriptor.name := To_Virtual_String (Instance.Instance_Name);
            Descriptor.relationships.Append (Relation);
            Descriptor.defaultConfiguration :=
              (Is_Set => True, Value => Make_Config (R_Id, Instance));
            Driver.rules.Append (Descriptor);
         end;
      end loop;

      --  Place the driver in the SARIF run object
      Run.tool := (driver => Driver, others => <>);

      --  Set the base URI of the run
      Run.originalUriBaseIds.Append ((Kind => Start_Object));
      Run.originalUriBaseIds.Append
        ((Kind => Key_Name, Key_Name => To_Virtual_String (Uri_Base_Dir_Id)));
      Run.originalUriBaseIds.Append ((Kind => Start_Object));
      Run.originalUriBaseIds.Append
        ((Kind => Key_Name, Key_Name => To_Virtual_String ("uri")));
      Run.originalUriBaseIds.Append
        ((Kind         => String_Value,
          String_Value =>
            To_Virtual_String
              (To_Uri (Uri_Base_Dir.Display_Full_Name (Normalize => True)))));
      Run.originalUriBaseIds.Append
        ((Kind => Key_Name, Key_Name => To_Virtual_String ("description")));
      Run.originalUriBaseIds.Append ((Kind => Start_Object));
      Run.originalUriBaseIds.Append
        ((Kind => Key_Name, Key_Name => To_Virtual_String ("text")));
      Run.originalUriBaseIds.Append
        ((Kind         => String_Value,
          String_Value =>
            To_Virtual_String
              ("Project directory if one has been used, working directory"
               & " otherwise")));
      Run.originalUriBaseIds.Append ((Kind => End_Object));
      Run.originalUriBaseIds.Append ((Kind => End_Object));
      Run.originalUriBaseIds.Append ((Kind => End_Object));

      --  Iterate over all diagnostics and build SARIF results
      for Diag of Collector.All_Error_Messages loop
         case Diag.Kind is
            when Rule_Violation =>
               --  When the result is a rule violation, create a result object
               declare
                  Res : ST.result;
                  Loc : constant ST.location :=
                    Make_Location
                      (Source_Name (Diag.SF),
                       Natural (Diag.Sloc.Line),
                       Natural (Diag.Sloc.Column));
               begin
                  Res.ruleId :=
                    To_Virtual_String
                      (To_Lower (Instance_Name (Diag.Instance.all)));
                  Res.level := (Is_Set => True, Value => SE.warning);
                  Res.message.text := To_Virtual_String (Diag.Text);
                  Res.locations.Append (Loc);
                  if Diag.Justification /= Null_Unbounded_String then
                     declare
                        Supp : ST.suppression;
                     begin
                        Supp.kind := SE.inSource;
                        Supp.location := (Is_Set => True, Value => Loc);
                        Supp.justification :=
                          To_Virtual_String (Diag.Justification);
                        Res.suppressions.Append (Supp);
                     end;
                  end if;
                  Run.results.Append (Res);
               end;

            when others         =>
               declare
                  Notif : ST.notification;
                  Loc   : constant ST.location :=
                    Make_Location
                      (Source_Name (Diag.SF),
                       Natural (Diag.Sloc.Line),
                       Natural (Diag.Sloc.Column));
                  Level : constant SE.notification_level :=
                    (if Diag.Kind = Exemption_Warning
                     then SE.warning
                     else SE.error);
               begin
                  Notif.message.text := To_Virtual_String (Diag.Text);
                  Notif.level := (Is_Set => True, Value => Level);
                  Notif.locations.Append (Loc);
                  Invocation.toolExecutionNotifications.Append (Notif);
               end;
         end case;
      end loop;

      --  Set useful information about the invocation
      Invocation.workingDirectory :=
        (Is_Set => True,
         Value  => Make_Artifact_Location (Normalize_Pathname ("./")));
      Invocation.commandLine := To_Virtual_String (Get_Command_Line);
      for Arg in 1 .. Ada.Command_Line.Argument_Count loop
         Invocation.arguments.Append
           (To_Virtual_String (Ada.Command_Line.Argument (Arg)));
      end loop;
      Invocation.environmentVariables.Append
        ((Kind => VSS.JSON.Streams.Start_Object));
      Iterate (Add_Env_Var'Access);
      Invocation.environmentVariables.Append
        ((Kind => VSS.JSON.Streams.End_Object));
      Invocation.startTimeUtc :=
        To_Virtual_String (Image (Start_Time, ISO_Time));
      Invocation.endTimeUtc := To_Virtual_String (Image (End_Time, ISO_Time));
      Invocation.exitCode := (Is_Set => True, Value => Exit_Code);
      Invocation.executionSuccessful :=
        Exit_Code = E_Success or else Exit_Code = E_Violation;
      Run.invocations.Append (Invocation);

      --  Assemble results in the SARIF root
      Root.runs.Append (Run);

      --  Write the final SARIF report as JSON in the output file
      Writer.Set_Stream (Mem'Unchecked_Access);
      Writer.Start_Document;
      ST.Outputs.Output_Root (Writer, Root);
      Writer.End_Document;
      Open_Or_Create (Output_File, Out_File, File);
      Put_Line
        (File,
         VSS.Stream_Element_Vectors.Conversions.Unchecked_To_String
           (Mem.Buffer));
      Close (File);
   end Generate_SARIF_Report;

end Lkql_Checker.Diagnostics.Report;
