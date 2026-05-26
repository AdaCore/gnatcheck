--
--  Copyright (C) 2005-2026, AdaCore
--  SPDX-License-Identifier: GPL-3.0-or-later
--

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Directories;         use Ada.Directories;
with Ada.Finalization;
with Ada.Strings;             use Ada.Strings;
with Ada.Strings.Fixed;       use Ada.Strings.Fixed;
with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;

with GNATCOLL.JSON;      use GNATCOLL.JSON;
with GNATCOLL.Opt_Parse; use GNATCOLL.Opt_Parse;

with GNAT.OS_Lib; use GNAT.OS_Lib;
with GNAT.Traceback.Symbolic;

with Lkql_Checker.Options;          use Lkql_Checker.Options;
with Lkql_Checker.String_Utilities; use Lkql_Checker.String_Utilities;

with Interfaces.C_Streams; use Interfaces.C_Streams;

package body Lkql_Checker.Output is

   --------------------
   -- Open_Or_Create --
   --------------------

   procedure Open_Or_Create
     (File_Path : String; Mode : File_Mode; File : in out File_Type) is
   begin
      if Is_Regular_File (File_Path) then
         Open (File, Mode, File_Path);
      else
         Create (File, Mode, File_Path);
      end if;
   exception
      when others =>
         Error ("can not open the file: " & File_Path);
         raise Fatal_Error;
   end Open_Or_Create;

   ------------------
   -- Output files --
   ------------------

   Log_File_Name : GNAT.OS_Lib.String_Access;
   --  Variables that set the properties of the tool report and log files

   XML_Report_File : File_Type;
   Report_File     : File_Type;
   Log_File        : File_Type;

   procedure Close_Report_File;
   procedure Close_XML_Report_File;
   --  Closes text/XML report file.

   --------------------
   -- Close_Log_File --
   --------------------

   procedure Close_Log_File is
   begin
      Close (Log_File);
      Free (Log_File_Name);
   end Close_Log_File;

   -----------------------
   -- Close_Report_File --
   -----------------------

   procedure Close_Report_File is
   begin
      --  This can be called on unhandled exceptions when we don't know the
      --  state of the Report_File, so we take care not to blow up.

      if Is_Open (Report_File) then
         Close (Report_File);
      end if;
   end Close_Report_File;

   ---------------------------
   -- Close_XML_Report_File --
   ---------------------------

   procedure Close_XML_Report_File is
   begin
      --  This can be called on unhandled exceptions when we don't know the
      --  state of the Report_File, so we take care not to blow up.

      if Is_Open (XML_Report_File) then
         Close (XML_Report_File);
      end if;
   end Close_XML_Report_File;

   ------------------------
   -- Close_Report_Files --
   ------------------------

   procedure Close_Report_Files is
   begin
      pragma
        Assert
          (Tool_Args.Text_Report_Enabled or else Tool_Args.XML_Report_Enabled);

      if Tool_Args.Text_Report_Enabled then
         Close_Report_File;
      end if;

      if Tool_Args.XML_Report_Enabled then
         Close_XML_Report_File;
      end if;
   end Close_Report_Files;

   ------------------
   -- Emit_Message --
   ------------------

   procedure Emit_Message
     (Message     : String;
      Tag         : Message_Tags := None;
      Tool_Name   : Boolean := False;
      Location    : String := "";
      New_Line    : Boolean := False;
      Log_Message : Boolean := False)
   is
      Final_Message : constant String :=
        (if Tool_Name then Lkql_Checker_Mode_Image & ": " else "")
        & (if Location /= "" then Location & ": " else "")
        & (case Tag is
             when Info    => "info: ",
             when Warning => "warning: ",
             when Error   => "error: ",
             when None    => "")
        & Message;
   begin
      --  Display the message in the standard error
      Put (Standard_Error, Final_Message);
      if New_Line then
         Ada.Text_IO.New_Line (Standard_Error);
      end if;

      --  If required, log the message
      if Log_Message
        and then Early_Args.Log_Enabled
        and then Is_Open (Log_File)
      then
         Put (Log_File, Final_Message);
         if New_Line then
            Ada.Text_IO.New_Line (Log_File);
         end if;
      end if;
   end Emit_Message;

   -----------
   -- Error --
   -----------

   procedure Error (Message : String; Location : String := "") is
   begin
      Emit_Message
        (Message,
         Tag         => Error,
         Tool_Name   => Location = "",
         Location    => Location,
         New_Line    => True,
         Log_Message => True);
   end Error;

   -----------------------
   -- Get_Indent_String --
   -----------------------

   function Get_Indent_String return String is
   begin
      return Indent_String;
   end Get_Indent_String;

   ----------------
   -- Get_Number --
   ----------------

   function Get_Number return String is
      Report_File_Name : constant String :=
        (if Tool_Args.Text_Report_Enabled
         then Tool_Args.Text_Report_File_Path
         else Tool_Args.XML_Report_File_Path);

      Idx_1, Idx_2 : Natural;
   begin
      if not GPR_Args.Aggregated_Project then
         return "";
      end if;

      Idx_2 := Index (Report_File_Name, ".", Backward);

      if Idx_2 = 0 then
         Idx_2 := Report_File_Name'Last;
      else
         Idx_2 := Idx_2 - 1;
      end if;

      Idx_1 :=
        Index
          (Report_File_Name (Report_File_Name'First .. Idx_2), "_", Backward);

      pragma Assert (Idx_1 > 0);
      pragma Assert (Idx_1 < Idx_2);

      return Report_File_Name (Idx_1 .. Idx_2);
   end Get_Number;

   ----------
   -- Info --
   ----------

   procedure Info (Message : String; Location : String := "") is
   begin
      Emit_Message
        (Message,
         Tag         => Info,
         Tool_Name   => Location = "",
         Location    => Location,
         New_Line    => True,
         Log_Message => True);
   end Info;

   -----------------
   -- Info_In_Tty --
   -----------------

   procedure Info_In_Tty (Message : String) is
   begin
      if isatty (fileno (stderr)) /= 0 then
         Emit_Message
           (Message,
            Tag         => Info,
            Tool_Name   => True,
            New_Line    => True,
            Log_Message => False);
      end if;
   end Info_In_Tty;

   -----------
   -- Print --
   -----------

   procedure Print (Message : String; New_Line, Log_Message : Boolean := True)
   is
   begin
      Emit_Message (Message, New_Line => New_Line, Log_Message => Log_Message);
   end Print;

   ------------------
   -- Print_In_Tty --
   ------------------

   procedure Print_In_Tty (Message : String; New_Line : Boolean := True) is
   begin
      if isatty (fileno (stderr)) /= 0 then
         Print (Message, New_Line => New_Line, Log_Message => False);
      end if;
   end Print_In_Tty;

   ------------------------
   -- Print_Version_Info --
   ------------------------

   procedure Print_Version_Info is
   begin
      Print (Lkql_Checker_Mode_Image & " " & Version_String);
      Print
        ("Copyright (C) " & "2004" & '-' & Current_Year & ", AdaCore.",
         Log_Message => False);
   end Print_Version_Info;

   ------------
   -- Report --
   ------------

   procedure Report (Message : String; Indent_Level : Natural := 0) is
   begin
      Report_No_EOL (Message, Indent_Level);
      Report_EOL;
   end Report;

   ----------------
   -- XML_Report --
   ----------------

   procedure XML_Report (Message : String; Indent_Level : Natural := 0) is
   begin
      XML_Report_No_EOL (Message, Indent_Level);
      XML_Report_EOL;
   end XML_Report;

   ----------------
   -- Report_EOL --
   ----------------

   procedure Report_EOL is
   begin
      New_Line (Report_File);
   end Report_EOL;

   --------------------
   -- XML_Report_EOL --
   --------------------

   procedure XML_Report_EOL is
   begin
      New_Line (XML_Report_File);
   end XML_Report_EOL;

   -------------------
   -- Report_No_EOL --
   -------------------

   procedure Report_No_EOL (Message : String; Indent_Level : Natural := 0) is
   begin
      for J in 1 .. Indent_Level loop
         Put (Report_File, Indent_String);
      end loop;

      Put (Report_File, Message);
   end Report_No_EOL;

   -----------------------
   -- XML_Report_No_EOL --
   -----------------------

   procedure XML_Report_No_EOL (Message : String; Indent_Level : Natural := 0)
   is
   begin
      for J in 1 .. Indent_Level loop
         Put (XML_Report_File, Indent_String);
      end loop;

      Put (XML_Report_File, Message);
   end XML_Report_No_EOL;

   --------------------------------
   -- Report_Unhandled_Exception --
   --------------------------------

   procedure Report_Unhandled_Exception (Ex : Exception_Occurrence) is
   begin
      Error (Exception_Message (Ex));
      if Tool_Args.Debug_Mode.Get then
         Print (GNAT.Traceback.Symbolic.Symbolic_Traceback_No_Hex (Ex));
      end if;
   end Report_Unhandled_Exception;

   -------------------------
   -- Report_Missing_File --
   -------------------------

   procedure Report_Missing_File (From_File, Missing_File : String) is
      function Format_Filename (F : String) return String
      is (if Tool_Args.Full_Source_Locations.Get then F else Simple_Name (F));
      --  Formats filename
   begin
      Warning
        (Format_Filename (From_File)
         & ": cannot find "
         & Format_Filename (Missing_File));

      Missing_File_Detected := True;
   end Report_Missing_File;

   ------------------
   -- Set_Log_File --
   ------------------

   procedure Open_Log_File is
   begin
      if Log_File_Name = null then
         Log_File_Name :=
           new String'
             (Global_Report_Dir.all & Lkql_Checker_Mode_Image & ".log");
      end if;

      Open_Or_Create (Log_File_Name.all, Out_File, Log_File);
   end Open_Log_File;

   ----------------------
   -- Set_Report_Files --
   ----------------------

   procedure Set_Report_Files is
   begin
      pragma
        Assert
          (Tool_Args.Text_Report_Enabled or else Tool_Args.XML_Report_Enabled);

      if Tool_Args.Text_Report_Enabled then
         Open_Or_Create
           (Tool_Args.Text_Report_File_Path, Out_File, Report_File);
      end if;

      if Tool_Args.XML_Report_Enabled then
         Open_Or_Create
           (Tool_Args.XML_Report_File_Path, Out_File, XML_Report_File);
      end if;
   end Set_Report_Files;

   -------------
   -- Warning --
   -------------

   procedure Warning (Message : String; Location : String := "") is
   begin
      if Tool_Args.Warnings_As_Errors.Get then
         Error (Message, Location);
         Error_From_Warning := True;
      else
         Emit_Message
           (Message,
            Tag         => Warning,
            Tool_Name   => Location = "",
            Location    => Location,
            New_Line    => True,
            Log_Message => True);
      end if;
   end Warning;

   ----------------

   --  We create a dummy object whose finalization calls Close_Report_File, so
   --  we don't leave stale lock files around even in case of unhandled
   --  exceptions.

   use Ada.Finalization;

   type Dummy_Type is new Limited_Controlled with null record;
   procedure Finalize (Ignore : in out Dummy_Type);
   procedure Finalize (Ignore : in out Dummy_Type) is
   begin
      Close_Report_File;
   end Finalize;

   Dummy : Dummy_Type;

   -----------------
   -- Print_Usage --
   -----------------

   procedure Print_Usage is

      function Is_Hidden_Option (Opt : JSON_Value) return Boolean
      is (Opt.Has_Field ("hidden") and then Boolean'(Opt.Get ("hidden")));
      --  Return True for options that should not appear in the help output.

      function Option_Left_Col (Opt : JSON_Value) return String;
      --  Build the left-column string for one option entry: flags followed by
      --  the argument placeholder for options that take a value.

      procedure Print_Section (Parser : Argument_Parser);
      --  Print the help section for one parser, driven by Parser.JSON_Help.

      function Option_Left_Col (Opt : JSON_Value) return String is
         Kind : constant String := Opt.Get ("kind");
         --  Parser kind: "flag", "option", "list_option", or
         --  "list_option_accumulate".

         Name : constant String := "<" & String'(Opt.Get ("name")) & ">";
         --  Argument placeholder in angle brackets, e.g. <file>.

         Short : constant String :=
           (if Opt.Has_Field ("short_flag")
            then Opt.Get ("short_flag")
            else "");
         --  Short flag string, e.g. "-r", or empty if absent.

         Long : constant String :=
           (if Opt.Has_Field ("long_flag") then Opt.Get ("long_flag") else "");
         --  Long flag string, e.g. "--rule", or empty if absent.

         Flags : constant String :=
           (if Short /= ""
            then Short & (if Long /= "" then ", " & Long else "")
            else Long);
      begin
         if Kind = "flag" then
            return Flags;
         elsif Kind = "list_option" then
            return Flags & " " & Name & " [" & Name & "...]";
         else
            return Flags & " " & Name;
         end if;
      end Option_Left_Col;

      procedure Print_Section (Parser : Argument_Parser) is
         JSON      : constant JSON_Value := Parser.JSON_Help;
         Header    : constant String := JSON.Get ("help");
         Opts      : constant JSON_Array := JSON.Get ("optional_parsers");
         Col_Width : Natural := 0;

         procedure Put_Option_Line (Flag_Col : String; Help : String);
         --  Print one option entry. If the flag + help fits on one line (using
         --  Col_Width for alignment), use single-line format; otherwise print
         --  the flag first and the wrapped help text indented below.

         procedure Put_Option_Line (Flag_Col : String; Help : String) is
            Indent  : constant String := 11 * ' ';
            Eff_Col : constant Natural :=
              Natural'Max (Col_Width, Flag_Col'Length);
            --  Effective column width: at least the flag's own length, so
            --  padding is always non-negative even for flags wider than
            --  Col_Width.
            Words   : constant String_Vector := Split (Help, ' ');
            Line    : Unbounded_String := To_Unbounded_String (Indent);
         begin
            --  Single-line format: " <flag><padding><help>", 80 chars max.
            --  1 (leading space) + Eff_Col (flag) + 2 (min gap) + help.
            if 1 + Eff_Col + 2 + Help'Length <= 80 then
               Put_Line
                 (" "
                  & Flag_Col
                  & (Eff_Col - Flag_Col'Length + 2) * ' '
                  & Help);
               return;
            end if;

            --  Two-line format: flag on its own line, help word-wrapped below.
            Put_Line (" " & Flag_Col);
            for Word of Words loop
               if Length (Line) = Indent'Length then
                  --  First word on the current line: always start it.
                  Append (Line, Word);
               elsif Length (Line) + 1 + Word'Length > 80 then
                  --  Word doesn't fit: flush the current line and start fresh.
                  Put_Line (To_String (Line));
                  Line := To_Unbounded_String (Indent & Word);
               else
                  Append (Line, ' ' & Word);
               end if;
            end loop;
            --  Flush the last (possibly only) line.
            if Length (Line) > Indent'Length then
               Put_Line (To_String (Line));
            end if;
         end Put_Option_Line;

      begin
         Put_Line (Header & ":");
         New_Line;

         --  First pass: compute the column width for flag alignment, only
         --  considering options whose flag + help can fit on a single line.
         for Opt of Opts loop
            if not Is_Hidden_Option (Opt) then
               declare
                  Flag : constant String := Option_Left_Col (Opt);
                  Help : constant String := Opt.Get ("help");
               begin
                  if 1 + Flag'Length + 2 + Help'Length <= 80 then
                     Col_Width := Natural'Max (Col_Width, Flag'Length);
                  end if;
               end;
            end if;
         end loop;

         --  Second pass: print each option with consistent alignment.
         for Opt of Opts loop
            if not Is_Hidden_Option (Opt) then
               Put_Option_Line (Option_Left_Col (Opt), Opt.Get ("help"));
            end if;
         end loop;

         New_Line;
      end Print_Section;

   begin
      if Mode = Gnatkp_Mode then
         Put_Line ("GNATkp: the GNAT known problem detector");
         New_Line;
         Put_Line ("Usage: gnatkp --RTS=<runtime> [-P<proj>] [name] [opts]");
      else
         Put_Line ("GNATcheck: the GNAT rule checking tool");
         New_Line;
         Put_Line ("Usage: gnatcheck [opts] [name] [-cargs opts]");
      end if;
      New_Line;
      Put_Line (" name is zero or more file names (wildcards allowed)");
      New_Line;

      Print_Section (Early_Args.Parser);
      Print_Section (Tool_Args.Parser);
      Print_Section (GPR_Args.Parser);

      New_Line;
      Put_Line ("Report bugs to support@adacore.com");
   end Print_Usage;

end Lkql_Checker.Output;
