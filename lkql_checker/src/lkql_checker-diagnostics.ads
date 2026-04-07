--
--  Copyright (C) 2005-2026, AdaCore
--  SPDX-License-Identifier: GPL-3.0-or-later
--

--  This package defines routines for storing diagnostic messages and
--  generating final report. It also provides routines that supports rule
--  exemption mechanism. Note, that most of the rule exemption mechanism is
--  hidden in the body of the package.

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Ordered_Sets;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with GNAT.Regpat; use GNAT.Regpat;

with Lkql_Checker.Ids;   use Lkql_Checker.Ids;
with Lkql_Checker.Rules; use Lkql_Checker.Rules;

with Langkit_Support.Slocs; use Langkit_Support.Slocs;

with Libadalang.Analysis;
with Libadalang.Common;

package Lkql_Checker.Diagnostics is

   package LAL renames Libadalang;

   --------------------------
   -- Diagnostics matching --
   --------------------------

   Match_Diagnostic : constant Pattern_Matcher :=
     Compile ("^(([A-Z]:)?[^:]*):(\d+):(\d+): (.*)$");
   --  Matcher for a diagnostic

   Match_Rule_Name : constant Pattern_Matcher :=
     Compile ("^""([^\s:]+)\s*(?::\s*(.*))?""$");
   --  Matcher for a rule name and potential arguments

   Match_Rule_Param : constant Pattern_Matcher := Compile ("([^,]+)?\s*,?\s*");

   Match_Rule_Warning_Param : constant Pattern_Matcher := Compile ("(\.?\w)");

   Common_Exempt_Comment_Match : constant String :=
     "\s+(line\s+)?(on|off)\s+([^\s]+)[^#]*(?:##(.*))?";

   Match_Rule_Exempt_Comment : constant Pattern_Matcher :=
     Compile ("--##\s*rule" & Common_Exempt_Comment_Match);

   Match_Kp_Exempt_Comment : constant Pattern_Matcher :=
     Compile ("--##\s*kp" & Common_Exempt_Comment_Match);

   -------------------------
   -- Diagnostics storage --
   -------------------------

   type Diagnostic_Kind is
     (Rule_Violation,
      --  Corresponds to all rule diagnostics, including compiler checks
      Exemption_Warning,
      --  Warnings generated for Annotate pragmas used to implement rule
      --  exemption mechanism.
      Compiler_Error,
      --  Compiler diagnostics generated for illegal (non-compilable) sources
      Internal_Error
      --  Internal tool error
     );

   type Diagnostic_Collector is limited private;
   --  A type to collect all diagnostics emitted during a checker run.

   procedure Store_Diagnostic
     (Collector : in out Diagnostic_Collector;
      Text      : String;
      Kind      : Diagnostic_Kind;
      SF        : SF_Id;
      Rule      : Rule_Id := No_Rule_Id;
      Instance  : Rule_Instance_Access := null);
   --  Stores a diagnostic expressed in ``Text`` with the other precisions.
   --  This function uses the other ``Store_Diagnostic`` to save the generated
   --  diagnostic in the internal data structure.

   procedure Store_Diagnostic
     (Collector      : in out Diagnostic_Collector;
      Full_File_Name : String;
      Message        : String;
      Sloc           : Source_Location;
      Kind           : Diagnostic_Kind;
      SF             : SF_Id;
      Rule           : Rule_Id := No_Rule_Id;
      Instance       : Rule_Instance_Access := null);
   --  Stores the diagnostic in the internal data structure. The same
   --  procedure is used for all diagnostic kinds; in case of
   --  Exemption_Warning, Compiler_Error and Internal_Error, Rule should be
   --  set to No_Rule_Id.

   function Sloc_Image (Line, Column : Natural) return String;
   function Sloc_Image (Sloc : Source_Location) return String;
   --  Return an image of line:column with Column having a leading '0' if less
   --  than 10.

   --------------------------
   -- Diagnostics Counters --
   --------------------------

   Detected_Non_Exempted_Violations : Natural := 0;
   Detected_Exempted_Violations     : Natural := 0;
   --  Separate counters for exempted and non-exempted violations.

   Detected_Exemption_Warning : Natural := 0;
   Detected_Compiler_Error    : Natural := 0;
   Detected_Internal_Error    : Natural := 0;

   -----------------------
   -- Report generation --
   -----------------------

   procedure Generate_Qualification_Report
     (Collector : in out Diagnostic_Collector);
   --  Generate the report oriented for using as qualification materials.
   --  There is no parameter to configure this report except
   --  Lkql_Checker.Options.Short_Report flag.

   procedure Print_Report_Header;
   --  Generates the report header, including the date, tool version and
   --  tool command liner invocation sequence. (We need it in spec because it
   --  is used by Lkql_Checker.Projects.Aggregate_Project_Report_Header.

   procedure Process_User_Filename (Fname : String);
   --  Checks if Fname is the name of the existing file. If it is, sets it as
   --  the value of Lkql_Checker.Options.User_Info_File, otherwise generates
   --  warning and leaves User_Info_File unchanged. If User_Info_File is
   --  already set, and Fname denotes some existing file, generates a warning
   --  (user-defined part of the report file can be specified only once!) and
   --  leaves User_Info_File unchanged.

   -------------------------
   -- Exemption mechanism --
   -------------------------

   function Is_Exemption_Pragma (El : LAL.Analysis.Pragma_Node) return Boolean;
   --  Checks if the argument Element is the Annotate or GNAT_Annotate pragma
   --  with the  first parameter equal to the current checker mode.

   procedure Process_Exemption_Pragma
     (Collector : in out Diagnostic_Collector; El : LAL.Analysis.Pragma_Node);
   --  Analyses the argument element and stores the
   --  information about exemption section. In most of the cases it is
   --  equivalent to turning the rule into exempted state, but for the
   --  following rule categories:
   --    * compiler checks
   --
   --  post-processing is needed. This postprocessing can be done when all the
   --  rule checking and processing of exemption pragmas on all the sources is
   --  completed.

   procedure Process_Exemption_Comment
     (Collector : in out Diagnostic_Collector;
      El        : LAL.Common.Token_Reference;
      Unit      : LAL.Analysis.Analysis_Unit);
   --  Process any comment from a source being analyzed. If it is an exemption
   --  comment, process it.
   --
   --  The logic is the same as ``Process_Exemption_Pragma``, only the syntax
   --  differs.

   procedure Check_Unclosed_Rule_Exemptions
     (Collector : in out Diagnostic_Collector;
      SF        : SF_Id;
      Unit      : LAL.Analysis.Analysis_Unit);
   --  Is supposed to be called in the very end of processing of the source
   --  corresponding to SF. Checks if there exist some exempted rules. For
   --  each such rule, a warning is issued and exemption is turned OFF. Unit
   --  parameter is used to compute the end of non-closed exemption sections
   --  for compiler checks, if any.

private

   -------------------------
   -- Diagnostics storage --
   -------------------------

   type Diagnostic is record
      File          : Unbounded_String;
      Sloc          : Source_Location;
      Text          : Unbounded_String;
      Justification : Unbounded_String;
      Kind          : Diagnostic_Kind;
      Rule          : Rule_Id;
      Instance      : Rule_Instance_Access;
      SF            : SF_Id;
   end record;

   function "<" (L, R : Diagnostic) return Boolean;

   package Error_Messages_Storage is new
     Ada.Containers.Ordered_Sets
       (Element_Type => Diagnostic,
        "="          => "=",
        "<"          => "<");

   --------------------------------------------------
   -- Data structures for rule exemption mechanism --
   --------------------------------------------------

   type Exemption_Info is record
      Line_Start : Natural;
      Col_Start  : Natural;
      --  Location of exemption pragma that turns exemption ON

      Line_End : Natural;
      Col_End  : Natural;
      --  End of the exemption section

      Justification : Unbounded_String;
      --  Justification for this exemption

      Exempted_Name : Unbounded_String;
      --  What is exempted: the rule name if the whole rule is exempted,
      --  otherwise this is the exempted instance name.

      Detected : Natural;
      --  Number of the diagnostics generated for exempted rule
   end record;

   package Exemption_Sections_Map is new
     Ada.Containers.Indefinite_Hashed_Maps
       (Key_Type        => Exemption_Id,
        Element_Type    => Exemption_Info,
        Hash            => Hash,
        Equivalent_Keys => "=");

   ---------------------------
   -- Parametric exemptions --
   ---------------------------

   type Parametrized_Exemption_Info is record
      Exempt_Info : Exemption_Info;
      Rule        : Rule_Id;
      SF          : SF_Id;
      Params      : Rule_Params;
   end record;

   type Param_Ex_Info_Key is record
      SF         : SF_Id;
      Line_Start : Natural;
      Col_Start  : Natural;
   end record;

   function Key
     (Element : Parametrized_Exemption_Info) return Param_Ex_Info_Key
   is (SF         => Element.SF,
       Line_Start => Element.Exempt_Info.Line_Start,
       Col_Start  => Element.Exempt_Info.Col_Start);

   function "<" (L, R : Param_Ex_Info_Key) return Boolean
   is (L.SF < R.SF
       or else (L.SF = R.SF
                and then (L.Line_Start < R.Line_Start
                          or else (L.Line_Start = R.Line_Start
                                   and then L.Col_Start < R.Col_Start))));

   use all type Rule_Params;

   function "=" (L, R : Parametrized_Exemption_Info) return Boolean
   is (L.SF = R.SF
       and then L.Params = R.Params
       and then L.Exempt_Info.Line_Start = R.Exempt_Info.Line_Start
       and then L.Exempt_Info.Col_Start = R.Exempt_Info.Col_Start);

   function "<" (L, R : Parametrized_Exemption_Info) return Boolean
   is (L.SF < R.SF
       or else (L.SF = R.SF
                and then (L.Exempt_Info.Line_Start < R.Exempt_Info.Line_Start
                          or else (L.Exempt_Info.Line_Start
                                   = R.Exempt_Info.Line_Start
                                   and then L.Exempt_Info.Col_Start
                                            < R.Exempt_Info.Col_Start))));

   package Parametrized_Exemption_Sections is new
     Ada.Containers.Ordered_Sets (Parametrized_Exemption_Info);

   package Exem_Section_Keys is new
     Parametrized_Exemption_Sections.Generic_Keys
       (Key_Type => Param_Ex_Info_Key,
        Key      => Key);

   package Rule_Param_Exempt_Sections_Map is new
     Ada.Containers.Indefinite_Hashed_Maps
       (Key_Type        => Exemption_Id,
        Element_Type    => Parametrized_Exemption_Sections.Set,
        Hash            => Hash,
        Equivalent_Keys => "=",
        "="             => Parametrized_Exemption_Sections."=");

   -------------------------------------
   -- Exemptions for postponed checks --
   -------------------------------------

   type Postponed_Rule_Exemption_Info;
   type Postponed_Rule_Exemption_Info_Access is
     access Postponed_Rule_Exemption_Info;

   type Postponed_Rule_Exemption_Info is record
      Exemption_Section      : Exemption_Info;
      Next_Exemption_Section : Postponed_Rule_Exemption_Info_Access;
   end record;

   type Postponed_Check_Exemption_Sections_Array is
     array (SF_Id range <>) of Postponed_Rule_Exemption_Info_Access;

   type Postponed_Check_Exemption_Sections_Array_Access is
     access Postponed_Check_Exemption_Sections_Array;

   package Postponed_Exemption_Sections_Map is new
     Ada.Containers.Indefinite_Hashed_Maps
       (Key_Type        => Exemption_Id,
        Element_Type    => Postponed_Check_Exemption_Sections_Array_Access,
        Hash            => Hash,
        Equivalent_Keys => "=");

   ------------------------------------------------
   -- Parametric exemptions for postponed checks --
   ------------------------------------------------

   type Per_Source_Postponed_Param_Exemp is
     array (SF_Id range <>) of Parametrized_Exemption_Sections.Set;

   type Per_Source_Postponed_Param_Exemp_Access is
     access Per_Source_Postponed_Param_Exemp;

   package Per_Rule_Postponed_Param_Exemp_Map is new
     Ada.Containers.Indefinite_Hashed_Maps
       (Key_Type        => Exemption_Id,
        Element_Type    => Per_Source_Postponed_Param_Exemp_Access,
        Hash            => Hash,
        Equivalent_Keys => "=");

   --------------------------
   -- Diagnostic_Collector --
   --------------------------

   type Diagnostic_Collector is limited record
      All_Error_Messages : Error_Messages_Storage.Set;
      --  All stored diagnostics, in order.

      Exemption_Sections : Exemption_Sections_Map.Map;
      --  Currently open (active) exemption sections, mapped from their
      --  rule identifier. Cannot be allocated statically because the
      --  number of rules is not known until all of them are registered.

      Rule_Param_Exempt_Sections : Rule_Param_Exempt_Sections_Map.Map;
      --  Parametric exemption sections mapped from their rule identifier.

      Postponed_Exemption_Sections : Postponed_Exemption_Sections_Map.Map;
      --  For each argument source, stores all the exemption sections
      --  found in this source, in the order they are processed. Sections
      --  for different kinds of checks are stored separately.

      Postponed_Param_Exempt_Sections : Per_Rule_Postponed_Param_Exemp_Map.Map;
      --  Parametric exemption sections for postponed checks, per rule.
   end record;

end Lkql_Checker.Diagnostics;
