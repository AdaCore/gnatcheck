--
--  Copyright (C) 2005-2026, AdaCore
--  SPDX-License-Identifier: GPL-3.0-or-later
--

with Ada.Strings;           use Ada.Strings;
with Ada.Strings.Fixed;     use Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with GNAT.Case_Util;

with Lkql_Checker.Compiler;         use Lkql_Checker.Compiler;
with Lkql_Checker.Rules;            use Lkql_Checker.Rules;
with Lkql_Checker.Rules.Rule_Table; use Lkql_Checker.Rules.Rule_Table;
with Lkql_Checker.Source_Table;     use Lkql_Checker.Source_Table;
with Lkql_Checker.String_Utilities; use Lkql_Checker.String_Utilities;

with GNATCOLL.Strings; use GNATCOLL.Strings;

with Langkit_Support.Slocs; use Langkit_Support.Slocs;
with Langkit_Support.Text;  use Langkit_Support.Text;

with Libadalang.Expr_Eval;

package body Lkql_Checker.Diagnostics.Exemptions is

   package LCO renames Libadalang.Common;

   ---------------------------------------------------------------------
   -- Data structures and local routines for rule exemption mechanism --
   ---------------------------------------------------------------------

   type Exemption_Kinds is (Not_An_Exemption, Exempt_On, Exempt_Off);

   function Get_Exemption_Kind
     (Image : Wide_Wide_String) return Exemption_Kinds;
   --  Returns Exemption_Kinds value represented by Image. Returns
   --  Not_An_Exemption if Image does not represent a valid exemption kind.

   -------------------
   -- Exempt_Action --
   -------------------

   type Exempt_Action is record
      Exemption_Control   : Exemption_Kinds;
      Exempted_Name       : Unbounded_String := Null_Unbounded_String;
      Params              : Rule_Params;
      Justification       : Unbounded_String := Null_Unbounded_String;
      Check_Justification : Boolean := True;
      Sloc_Range          : Langkit_Support.Slocs.Source_Location_Range;
      Unit                : LAL.Analysis.Analysis_Unit;
   end record;
   --  Stores information about an exemption action (either triggered by
   --  a ``pragma Annotate``, or by a ``--#`` comment).
   --
   --  This type and the associated primitive are used to decouple the
   --  validation and processing of the action, and are used both by
   --  comment based exemptions and pragma based ones.

   procedure Process_Exempt_Action
     (Collector : in out Diagnostic_Collector; Self : Exempt_Action);
   --  Process the given exempt action, doing some legality checks on
   --  the Exempt_Action, and creating the necessary exemption
   --  information in the sections arrays.

   procedure Turn_Off_Exemption
     (Collector    : in out Diagnostic_Collector;
      Id           : Exemption_Id;
      Closing_Sloc : Source_Location;
      SF           : SF_Id);
   --  Cleans up the stored exemption section for ``Id``.

   function Parse_Exempt_Parameters
     (Collector : in out Diagnostic_Collector;
      Rule      : Rule_Id;
      Input     : String;
      SF        : SF_Id;
      SLOC      : String) return Exemption_Parameters.Set;
   --  Assuming that ``Rule`` is a rule that allows parametric
   --  expressions, and ``Input`` contains rule parameters, parses
   --  ``Input`` string and checks if each of the specified parameters
   --  indeed can be used as rule exemption parameter. Returns a parsed
   --  set of parameters.
   --
   --  If parameters are incorrect, diagnostics will be generated with
   --  the given ``SF`` and ``SLOC``.

   function Allows_Parametrized_Exemption (Rule : Rule_Id) return Boolean;
   --  Checks if Rule allows fine-tuned exemption (with specifying
   --  parameters for that it can be exempted). Assumes Present (Rule).

   function Allowed_As_Exemption_Parameter
     (Rule : Rule_Id; Param : String) return Boolean;
   --  Checks if Param is allowed as a rule parameter in rule exemption
   --  pragma. Assumes that Param has already folded to lower case.
   --  Always returns False if Allows_Parametrized_Exemption (Rule) is
   --  False.

   function Exemption_Section_With_Params
     (Collector : Diagnostic_Collector;
      Id        : Exemption_Id;
      Params    : Exemption_Parameters.Set)
      return Parametrized_Exemption_Sections.Cursor;
   --  Checks if an exemption with the given ``Id`` already exists with
   --  the set of parameters that are stored in ``Params``.
   --  If it is, then return a cursor pointing to the corresponding
   --  exemption section in Collector.Rule_Param_Exempt_Sections,
   --  otherwise return ``No_Element``.

   function Exemption_Section_With_One_Param
     (Collector : Diagnostic_Collector;
      Id        : Exemption_Id;
      Params    : Exemption_Parameters.Set;
      Par       : out Unbounded_String)
      return Parametrized_Exemption_Sections.Cursor;
   --  Is similar to the previous procedure, but it checks that there
   --  is at least one parameter in ``Params`` that has already been
   --  used in definition of some opened parametric exception section
   --  for this rule. If the checks succeeds, ``Par`` is set to point
   --  to this parameter.

   function Get_Param_Justification
     (Collector : Diagnostic_Collector;
      Name      : String;
      Rule      : Rule_Id;
      Diag      : String;
      SF        : SF_Id;
      Line      : Natural;
      Col       : Natural) return Unbounded_String;
   --  With ``Diag`` being the message of a violation of the given
   --  ``Rule`` emitted under the given ``Name`` (instance name). If
   --  this ``Name`` is exempted with the parameter described by
   --  ``Diag`` at the position described by ``Line`` and ``Col`` in
   --  ``SF`` file, then, return the justification for this exemption.
   --  Else returns a null unbounded string.

   function Rule_Parameter (Diag : String; Rule : Rule_Id) return String;
   --  Provided that Rule allows parametric exemptions, and Diag is a
   --  diagnostic message corresponding to this rule, defines the rule
   --  exemption parameter Diag corresponds to.

   function Get_Exem_Section
     (Exem_Sections : Parametrized_Exemption_Sections.Set;
      Param         : String;
      Line          : Natural;
      Col           : Natural) return Parametrized_Exemption_Sections.Cursor;
   --  Tries to locate in Exem_Sections the section that exempts the
   --  rule this Param is supposed to correspond to (choosing the right
   --  set of exemption sections should be done outside the call) with
   --  Param.  Returns No_Element if the attempt fails.

   procedure Increase_Diag_Counter
     (Exem_Sections : in out Parametrized_Exemption_Sections.Set;
      Section       : Parametrized_Exemption_Sections.Cursor);
   --  Adds 1 to the counter of detected violations for the exemption
   --  sections pointed by Section in Exem_Sections.

   procedure Turn_Off_Parametrized_Exemption
     (Collector    : in out Diagnostic_Collector;
      Id           : Exemption_Id;
      Exempted_At  : in out Parametrized_Exemption_Sections.Cursor;
      Closing_Sloc : Source_Location;
      SF           : SF_Id);
   --  Cleans up the stored exemption section for the argument Rule.

   procedure Map_On_Postponed_Check_Exemption
     (Collector     : in out Diagnostic_Collector;
      In_File       : SF_Id;
      For_Name      : String;
      For_Line      : Positive;
      Is_Exempted   : out Boolean;
      Justification : in out Unbounded_String);
   --  This procedure checks if For_Line parameter gets into the
   --  corresponding exemption section and sets Is_Exempted accordingly.
   --  If Is_Exempted is set to True, Justification is set to the
   --  relevant Justification.

   function Is_Exempted
     (Collector : Diagnostic_Collector; Id : Exemption_Id) return Boolean
   is (Collector.Exemption_Sections.Contains (Id)
       and then Collector.Exemption_Sections (Id).Line_Start > 0);
   --  Checks if the given exemption identified by ``Id`` is in
   --  exempted state

   function Is_Param_Exempted
     (Collector : Diagnostic_Collector; Id : Exemption_Id) return Boolean
   is (Collector.Rule_Param_Exempt_Sections.Contains (Id)
       and then not Collector.Rule_Param_Exempt_Sections (Id).Is_Empty);
   --  Returns whether an exemption with the given ``Id`` already
   --  exists with any actual parameters.

   function Params_Img (Params : Rule_Params; Rule : Rule_Id) return String;
   --  Returns an image of Params for display in diagnostics about the
   --  exemption mechanism.

   ------------------------------------
   -- Allowed_As_Exemption_Parameter --
   ------------------------------------

   function Allowed_As_Exemption_Parameter
     (Rule : Rule_Id; Param : String) return Boolean is
   begin
      if not Allows_Parametrized_Exemption (Rule) then
         return False;
      end if;

      if Rule = Restrictions_Id then
         return Is_Restriction_Exemption_Par (Param);
      elsif Rule = Style_Checks_Id then
         return Is_Style_Exemption_Par (Param);
      elsif Rule = Warnings_Id then
         return Is_Warning_Exemption_Par (Param);
      else
         return All_Rules (Rule).Allowed_As_Exemption_Parameter (Param);
      end if;
   end Allowed_As_Exemption_Parameter;

   -----------------------------------
   -- Allows_Parametrized_Exemption --
   -----------------------------------

   function Allows_Parametrized_Exemption (Rule : Rule_Id) return Boolean is
   begin
      if Is_Compiler_Rule (Rule) then
         return True;
      else
         return All_Rules (Rule).Allows_Parametrized_Exemption;
      end if;
   end Allows_Parametrized_Exemption;

   ------------------------------------
   -- Check_Unclosed_Rule_Exemptions --
   ------------------------------------

   procedure Check_Unclosed_Rule_Exemptions
     (Collector : in out Diagnostic_Collector;
      SF        : SF_Id;
      Unit      : LAL.Analysis.Analysis_Unit)
   is
      use Parametrized_Exemption_Sections;

      Sloc         : constant Source_Location :=
        End_Sloc (Unit.Root.Sloc_Range);
      Next_Section : Cursor;
      Id           : Exemption_Id;
      To_Turn_Off  : Exemption_Id_Vec.Vector;
   begin
      --  Non-parametric exemptions
      for Cursor in Collector.Exemption_Sections.Iterate loop
         Id := Exemption_Sections_Map.Key (Cursor);
         if Is_Exempted (Collector, Id) then
            Store_Diagnostic
              (Collector,
               Full_File_Name => File_Name (SF),
               Sloc           =>
                 (Line_Number (Collector.Exemption_Sections (Id).Line_Start),
                  Column_Number (Collector.Exemption_Sections (Id).Col_Start)),
               Message        =>
                 "no matching 'exempt_OFF' annotation for "
                 & To_String (Collector.Exemption_Sections (Id).Exempted_Name),
               Kind           => Exemption_Warning,
               SF             => SF);
            To_Turn_Off.Append (Id);
         end if;
      end loop;

      for Cursor in To_Turn_Off.Iterate loop
         Turn_Off_Exemption
           (Collector,
            Id           => To_Turn_Off (Cursor),
            Closing_Sloc => Sloc,
            SF           => SF);
      end loop;
      To_Turn_Off.Clear;

      --  Parametric exemptions
      for Cursor in Collector.Rule_Param_Exempt_Sections.Iterate loop
         Id := Rule_Param_Exempt_Sections_Map.Key (Cursor);
         if not Is_Empty (Collector.Rule_Param_Exempt_Sections (Cursor)) then
            --  We cannot use set iterator here - we need to use Id and
            --  SF into processing routine
            Next_Section :=
              First (Collector.Rule_Param_Exempt_Sections (Cursor));

            while Has_Element (Next_Section) loop
               Store_Diagnostic
                 (Collector,
                  Full_File_Name => Short_Source_Name (SF),
                  Sloc           =>
                    (Line_Number
                       (Element (Next_Section).Exempt_Info.Line_Start),
                     Column_Number
                       (Element (Next_Section).Exempt_Info.Col_Start)),
                  Message        =>
                    "no matching 'exempt_OFF' annotation for "
                    & To_String
                        (Element (Next_Section).Exempt_Info.Exempted_Name),
                  Kind           => Exemption_Warning,
                  SF             => SF);
               Turn_Off_Parametrized_Exemption
                 (Collector, Id, Next_Section, Sloc, SF);
               Next_Section :=
                 First (Collector.Rule_Param_Exempt_Sections (Cursor));
            end loop;
         end if;
      end loop;
   end Check_Unclosed_Rule_Exemptions;

   -----------------------------------
   -- Exemption_Section_With_Params --
   -----------------------------------

   function Exemption_Section_With_Params
     (Collector : Diagnostic_Collector;
      Id        : Exemption_Id;
      Params    : Exemption_Parameters.Set)
      return Parametrized_Exemption_Sections.Cursor
   is
      use Parametrized_Exemption_Sections;
      Next_Section : Cursor;
   begin
      if Is_Param_Exempted (Collector, Id) then
         Next_Section := First (Collector.Rule_Param_Exempt_Sections (Id));

         while Has_Element (Next_Section) loop
            if Params = Element (Next_Section).Params then
               return Next_Section;
            end if;
            Next_Section := Next (Next_Section);
         end loop;
      end if;

      return No_Element;
   end Exemption_Section_With_Params;

   --------------------------------------
   -- Exemption_Section_With_One_Param --
   --------------------------------------

   function Exemption_Section_With_One_Param
     (Collector : Diagnostic_Collector;
      Id        : Exemption_Id;
      Params    : Exemption_Parameters.Set;
      Par       : out Unbounded_String)
      return Parametrized_Exemption_Sections.Cursor
   is
      Next_Par     : Exemption_Parameters.Cursor :=
        Exemption_Parameters.First (Params);
      Next_Section : Parametrized_Exemption_Sections.Cursor;
   begin
      if Is_Param_Exempted (Collector, Id) then
         while Exemption_Parameters.Has_Element (Next_Par) loop
            Next_Section :=
              Parametrized_Exemption_Sections.First
                (Collector.Rule_Param_Exempt_Sections (Id));

            while Parametrized_Exemption_Sections.Has_Element (Next_Section)
            loop
               if Parametrized_Exemption_Sections.Element (Next_Section)
                    .Params
                    .Contains (Exemption_Parameters.Element (Next_Par))
               then
                  Par :=
                    To_Unbounded_String
                      (Exemption_Parameters.Element (Next_Par));
                  return Next_Section;
               end if;

               Next_Section :=
                 Parametrized_Exemption_Sections.Next (Next_Section);
            end loop;

            Next_Par := Exemption_Parameters.Next (Next_Par);
         end loop;
      end if;

      return Parametrized_Exemption_Sections.No_Element;
   end Exemption_Section_With_One_Param;

   ----------------------
   -- Get_Exem_Section --
   ----------------------

   function Get_Exem_Section
     (Exem_Sections : Parametrized_Exemption_Sections.Set;
      Param         : String;
      Line          : Natural;
      Col           : Natural) return Parametrized_Exemption_Sections.Cursor
   is
      use Parametrized_Exemption_Sections;

      Result       : Cursor := No_Element;
      Next_Section : Cursor := First (Exem_Sections);

      Diag_In_Section      : Boolean := True;
      Diag_Before_Sections : Boolean := False;
      --  Control iterating through all the parametric exemption
      --  sections for the source that are stored in Exem_Sections

      Next_Section_El : Parametrized_Exemption_Info;
   begin
      while Has_Element (Next_Section) loop
         Next_Section_El := Element (Next_Section);

         Diag_Before_Sections :=
           Line < Next_Section_El.Exempt_Info.Line_Start
           or else (Line = Next_Section_El.Exempt_Info.Line_Start
                    and then Col < Next_Section_El.Exempt_Info.Col_Start);

         exit when Diag_Before_Sections;

         Diag_In_Section :=
           (Line > Next_Section_El.Exempt_Info.Line_Start
            or else (Line = Next_Section_El.Exempt_Info.Line_Start
                     and then Col > Next_Section_El.Exempt_Info.Col_Start))
           and then (Line < Next_Section_El.Exempt_Info.Line_End
                     or else (Line = Next_Section_El.Exempt_Info.Line_End
                              and then Col
                                       < Next_Section_El.Exempt_Info.Col_End));

         if Diag_In_Section and then Next_Section_El.Params.Contains (Param)
         then
            Result := Next_Section;
            exit;
         end if;

         Next_Section := Next (Next_Section);
      end loop;

      return Result;
   end Get_Exem_Section;

   ------------------------
   -- Get_Exemption_Kind --
   ------------------------

   function Get_Exemption_Kind
     (Image : Wide_Wide_String) return Exemption_Kinds
   is
      Norm_Image : constant Wide_Wide_String :=
        To_Lower
          (if Image (Image'First) = '"'
           then Image (Image'First + 1 .. Image'Last - 1)
           else Image);
   begin
      if Norm_Image = "exempt_on" then
         return Exempt_On;
      elsif Norm_Image = "exempt_off" then
         return Exempt_Off;
      else
         return Not_An_Exemption;
      end if;
   end Get_Exemption_Kind;

   -----------------------------
   -- Get_Param_Justification --
   -----------------------------

   function Get_Param_Justification
     (Collector : Diagnostic_Collector;
      Name      : String;
      Rule      : Rule_Id;
      Diag      : String;
      SF        : SF_Id;
      Line      : Natural;
      Col       : Natural) return Unbounded_String
   is
      use Parametrized_Exemption_Sections;

      Id               : constant Exemption_Id := Find_Exemption_Id (Name);
      Matching_Section : Cursor;
   begin
      --  Check if the given name is exempted at the given location
      --  with the given params.
      if Collector.Postponed_Param_Exempt_Sections.Contains (Id) then
         declare
            Exem_Sections : Parametrized_Exemption_Sections.Set renames
              Collector.Postponed_Param_Exempt_Sections (Id) (SF);
            Param         : constant String := Rule_Parameter (Diag, Rule);
            pragma Assert (Param /= "" or else Rule = Warnings_Id);
         begin
            if not Is_Empty
                     (Collector.Postponed_Param_Exempt_Sections (Id) (SF))
            then
               Matching_Section :=
                 Get_Exem_Section (Exem_Sections, Param, Line, Col);

               if Has_Element (Matching_Section) then
                  Increase_Diag_Counter (Exem_Sections, Matching_Section);
                  return Element (Matching_Section).Exempt_Info.Justification;
               end if;
            end if;
         end;
      end if;

      --  Return the default result when nothing is found
      return Null_Unbounded_String;
   end Get_Param_Justification;

   ---------------------------
   -- Increase_Diag_Counter --
   ---------------------------

   procedure Increase_Diag_Counter
     (Exem_Sections : in out Parametrized_Exemption_Sections.Set;
      Section       : Parametrized_Exemption_Sections.Cursor)
   is
      procedure Add_One (Exem_Section : in out Parametrized_Exemption_Info);

      procedure Add_One (Exem_Section : in out Parametrized_Exemption_Info) is
      begin
         Exem_Section.Exempt_Info.Detected := @ + 1;
      end Add_One;
   begin
      Exem_Section_Keys.Update_Element_Preserving_Key
        (Container => Exem_Sections,
         Position  => Section,
         Process   => Add_One'Access);
   end Increase_Diag_Counter;

   -------------------------
   -- Is_Exemption_Pragma --
   -------------------------

   function Is_Exemption_Pragma (El : LAL.Analysis.Pragma_Node) return Boolean
   is
      Pragma_Name : constant Text_Type := To_Lower (El.F_Id.Text);
      Pragma_Args : constant LAL.Analysis.Base_Assoc_List := El.F_Args;
      Tool_Name   : constant Text_Type := To_Text (Lkql_Checker_Mode_Image);
   begin
      return
        Pragma_Name in "annotate" | "gnat_annotate"
        and then not Pragma_Args.Is_Null
        and then To_Lower (Pragma_Args.List_Child (1).P_Assoc_Expr.Text)
                 = Tool_Name;
   end Is_Exemption_Pragma;

   --------------------------------------
   -- Map_On_Postponed_Check_Exemption --
   --------------------------------------

   procedure Map_On_Postponed_Check_Exemption
     (Collector     : in out Diagnostic_Collector;
      In_File       : SF_Id;
      For_Name      : String;
      For_Line      : Positive;
      Is_Exempted   : out Boolean;
      Justification : in out Unbounded_String)
   is
      Id : constant Exemption_Id := Find_Exemption_Id (For_Name);
   begin
      --  Initialize the output value to false
      Is_Exempted := False;

      --  Exemption sections are processed in argument files only. Also
      --  rule must be exempted.
      if Collector.Postponed_Exemption_Sections.Contains (Id)
        and then Is_Argument_Source (In_File)
      then
         --  Traverse exemption sections
         for Section of
           Collector.Postponed_Exemption_Sections.Reference (Id) (In_File)
         loop
            if For_Line in Section.Line_Start .. Section.Line_End then
               Is_Exempted := True;
               Section.Detected := @ + 1;
               Justification := Section.Justification;
               exit;
            end if;
         end loop;
      end if;
   end Map_On_Postponed_Check_Exemption;

   ----------------
   -- Params_Img --
   ----------------

   function Params_Img (Params : Rule_Params; Rule : Rule_Id) return String is
      Res   : Unbounded_String;
      Count : Natural := 0;
   begin
      for El of Params loop
         if Count > 0 then
            Append (Res, ", ");
         end if;

         Append
           (Res,
            (if Rule in Warnings_Id | Style_Checks_Id
             then El
             else GNAT.Case_Util.To_Mixed (El)));

         Count := Count + 1;
      end loop;

      return To_String (Res);
   end Params_Img;

   -----------------------------
   -- Parse_Exempt_Parameters --
   -----------------------------

   function Parse_Exempt_Parameters
     (Collector : in out Diagnostic_Collector;
      Rule      : Rule_Id;
      Input     : String;
      SF        : SF_Id;
      SLOC      : String) return Exemption_Parameters.Set
   is
      use Lkql_Checker.Rules.Exemption_Parameters;

      Is_Warning : constant Boolean := Rule in Warnings_Id | Style_Checks_Id;
      --  In case of Warnings rule, we consider parameters one by one.
      --  That is, for "ad.c.d.fg" as Input string we separately store
      --  'a', 'd', '.c', '.d', '.f' and 'g'

      Params        : Exemption_Parameters.Set;
      Current       : Natural := Input'First;
      Matches       : Match_Array (0 .. 1);
      Param_Matcher : constant Pattern_Matcher :=
        (if Is_Warning then Match_Rule_Warning_Param else Match_Rule_Param);
   begin
      loop
         Match (Param_Matcher, Input, Matches, Current);
         exit when Matches (0) = No_Match;

         declare
            Success  : Boolean;
            Position : Exemption_Parameters.Cursor;
            Stripped : constant String :=
              Remove_Spaces (Input (Matches (1).First .. Matches (1).Last));
            Param    : constant String :=
              (if Is_Warning
               then Stripped
               else GNAT.Case_Util.To_Lower (Stripped));
         begin
            if Allowed_As_Exemption_Parameter (Rule, Param) then
               Params.Insert (Param, Position, Success);

               if not Success then
                  Store_Diagnostic
                    (Collector,
                     Text =>
                       File_Name (SF)
                       & ":"
                       & SLOC
                       & ": parameter "
                       & Param
                       & " duplicated in exemption",
                     Kind => Exemption_Warning,
                     SF   => SF);
               end if;
            else
               Store_Diagnostic
                 (Collector,
                  Text =>
                    File_Name (SF)
                    & ":"
                    & SLOC
                    & ": parameter "
                    & Param
                    & " is not allowed in exemption for rule "
                    & Rule_Name (Rule),
                  Kind => Exemption_Warning,
                  SF   => SF);
            end if;
         end;

         Current := Matches (0).Last + 1;
         exit when Current > Input'Last;
      end loop;

      return Params;
   end Parse_Exempt_Parameters;

   ---------------------------
   -- Process_Exempt_Action --
   ---------------------------

   procedure Process_Exempt_Action
     (Collector : in out Diagnostic_Collector; Self : Exempt_Action)
   is
      use Parametrized_Exemption_Sections;

      SF            : constant SF_Id := File_Find (Self.Unit.Get_Filename);
      Sloc_Start    : constant Source_Location :=
        Langkit_Support.Slocs.Start_Sloc (Self.Sloc_Range);
      Sloc_End      : constant Source_Location :=
        Langkit_Support.Slocs.End_Sloc (Self.Sloc_Range);
      Has_Params    : constant Boolean := not Self.Params.Is_Empty;
      Exempted_Name : constant String := To_String (Self.Exempted_Name);
      Rule          : constant Rule_Id := Get_Rule (Exempted_Name);
      Instance      : constant Rule_Instance_Access :=
        Get_Instance (Exempted_Name);
      R_Name        : constant String :=
        (if Present (Rule) then Rule_Name (Rule) else "");

      Id   : constant Exemption_Id := Find_Exemption_Id (Exempted_Name);
      R_Id : constant Exemption_Id := Find_Exemption_Id (R_Name);

      Exempted_At : Cursor;
      Action      : Exempt_Action := Self;
      Param       : Unbounded_String;

      procedure Exempt_Diag (Msg : String);
      --  Store a new diagnostic about the current processed exempt
      --  action

      procedure Exempt_Diag (Msg : String) is
      begin
         Store_Diagnostic
           (Collector,
            Full_File_Name => Self.Unit.Get_Filename,
            Sloc           => Sloc_Start,
            Message        => Msg,
            Kind           => Exemption_Warning,
            SF             => SF);
      end Exempt_Diag;

   begin
      --  Ensure that the action is a valid exemption
      if Self.Exemption_Control = Not_An_Exemption then
         Exempt_Diag ("wrong exemption kind, ignored");
         return;
      end if;

      --  Check if we have a rule corresponding to the provided name
      if not Present (Rule) then
         Exempt_Diag
           ("wrong rule or instance name in exemption ("
            & Exempted_Name
            & "), ignored");
         return;
      end if;

      --  Verify that, if the instance is an alias, the rule is not a
      --  compiler-based one.
      if Is_Compiler_Rule (Rule)
        and then Instance /= null
        and then Instance.Is_Alias
      then
         Exempt_Diag
           ("cannot exempt a specific instance of a compiler rule ("
            & R_Name
            & "), ignored");
         return;
      end if;

      --  Verify that, if the rule has params, it's allowed to have
      --  some
      if Has_Params and then not Allows_Parametrized_Exemption (Rule) then
         Exempt_Diag
           ("rule "
            & R_Name
            & " cannot have parametric exemption, "
            & "ignored");
         return;
      end if;

      --  Justification is not expected (and shouldn't be present) if
      --  the action is to turn off an exemption.
      if Action.Exemption_Control = Exempt_Off
        and then Action.Justification /= Null_Unbounded_String
        and then Action.Check_Justification
      then
         Exempt_Diag ("turning exemption OFF does not need justification");
      end if;

      --  If exemption is turned ON, justification is expected
      if Action.Exemption_Control = Exempt_On
        and then Action.Justification = Null_Unbounded_String
        and then Action.Check_Justification
      then
         Exempt_Diag ("turning exemption ON expects justification");
      end if;

      --  If `Rule` is not enabled - nothing to do
      if not (Is_Enabled (Rule)
              or else (Rule = Warnings_Id
                       and then Is_Enabled (Restrictions_Id)))
      then
         --  In case when a Restriction rule is enabled, we may want to
         --  use exemptions section for Warnings rule to suppress
         --  default warnings. We may get rid of this if and when we
         --  get a possibility to turn off all the warnings except
         --  related to restrictions only.
         return;

      elsif Rule = Restrictions_Id and then Has_Params then
         --  If the exempted rule is "Restrictions" and there are
         --  parameters, we want to ensure that at least one of the
         --  specified restrictions is enabled.
         declare
            Active_Found : Boolean := False;
         begin
            for Param of Action.Params loop
               declare
                  Sep_Idx          : constant Natural := Index (Param, "=");
                  Restriction_Name : constant String :=
                    (if Sep_Idx = 0
                     then Param
                     else Param (Param'First .. Sep_Idx - 1));
               begin
                  if Is_Restriction_Active (Restriction_Name) then
                     Active_Found := True;
                  end if;
               end;
            end loop;
            if not Active_Found then
               return;
            end if;
         end;
      end if;

      --  Now - processing of the exemption action. If we are here, we
      --  are sure that Rule denotes an existing and enabled rule.
      case Action.Exemption_Control is
         when Exempt_On        =>
            if Action.Justification = Null_Unbounded_String then
               Action.Justification := To_Unbounded_String ("unjustified");
            end if;

            --  Ensure that the name isn't already exempted
            if Is_Exempted (Collector, Id) then
               Exempt_Diag
                 ((if Id = R_Id then "rule " else "instance ")
                  & Exempted_Name
                  & " is already exempted at line"
                  & Collector.Exemption_Sections (Id).Line_Start'Img);
               return;
            elsif Id /= R_Id and then Is_Exempted (Collector, R_Id) then
               Exempt_Diag
                 ("rule "
                  & R_Name
                  & " is already exempted at line"
                  & Collector.Exemption_Sections (R_Id).Line_Start'Img);
               return;
            end if;

            --  If the exemption has no provided parameters
            if not Has_Params then
               --  Check that the object is not already exempted with
               --  parameters.
               if Allows_Parametrized_Exemption (Rule) then
                  if Is_Param_Exempted (Collector, Id) then
                     Exempt_Diag
                       ((if Id = R_Id then "rule " else "instance ")
                        & Exempted_Name
                        & " is already exempted with parameter(s)"
                        & " at line"
                        & Element
                            (First (Collector.Rule_Param_Exempt_Sections (Id)))
                            .Exempt_Info
                            .Line_Start'Img);
                     return;
                  elsif Id /= R_Id and then Is_Param_Exempted (Collector, R_Id)
                  then
                     Exempt_Diag
                       ("rule "
                        & R_Name
                        & " is already exempted with parameter(s)"
                        & " at line"
                        & Element
                            (First
                               (Collector.Rule_Param_Exempt_Sections (R_Id)))
                            .Exempt_Info
                            .Line_Start'Img);
                     return;
                  end if;
               end if;

               --  If the exemption is valid insert it in the exemption
               --  sections map.
               Collector.Exemption_Sections.Insert
                 (Id,
                  (Line_Start    => Natural (Sloc_Start.Line),
                   Col_Start     => Natural (Sloc_Start.Column),
                   Line_End      => 0,
                   Col_End       => 0,
                   Justification => Action.Justification,
                   Exempted_Name => To_Unbounded_String (Exempted_Name),
                   Detected      => 0));

            --  Else, some actual parameters have been provided

            else
               --  Check that the object is not exempted with the same
               --  params
               Exempted_At :=
                 Exemption_Section_With_Params (Collector, Id, Action.Params);

               if Has_Element (Exempted_At) then
                  Exempt_Diag
                    ((if Id = R_Id then "rule " else "instance ")
                     & Exempted_Name
                     & " is already exempted with the same parameter(s)"
                     & " at line"
                     & Element (Exempted_At).Exempt_Info.Line_Start'Img);
                  return;
               end if;

               --  Check that the object is not exempted with one of
               --  the provided params
               Exempted_At :=
                 Exemption_Section_With_One_Param
                   (Collector, Id, Action.Params, Param);

               if Has_Element (Exempted_At) then
                  Exempt_Diag
                    ((if Id = R_Id then "rule " else "instance ")
                     & Exempted_Name
                     & " is already exempted with parameter '"
                     & To_String (Param)
                     & "' at line"
                     & Element (Exempted_At).Exempt_Info.Line_Start'Img);
                  return;
               end if;

               --  If we are exempting a rule instance, make sure the
               --  rule is not already exempted with one of the same
               --  params
               if Id /= R_Id then
                  Exempted_At :=
                    Exemption_Section_With_One_Param
                      (Collector, R_Id, Action.Params, Param);

                  if Has_Element (Exempted_At) then
                     Exempt_Diag
                       ("rule "
                        & R_Name
                        & " is already exempted with parameter '"
                        & To_String (Param)
                        & "' at line"
                        & Element (Exempted_At).Exempt_Info.Line_Start'Img);
                     return;
                  end if;
               end if;

               --  If we are here then we know for sure that the
               --  parametric exemption is correct, and there is no
               --  open exemption section for this rule and this
               --  parameter(s). So we can just add the corresponding
               --  record to Collector.Rule_Param_Exempt_Sections:
               if not Collector.Rule_Param_Exempt_Sections.Contains (Id) then
                  Collector.Rule_Param_Exempt_Sections.Insert (Id, Empty);
               end if;
               Insert
                 (Collector.Rule_Param_Exempt_Sections (Id),
                  (Exempt_Info =>
                     (Line_Start    => Natural (Sloc_Start.Line),
                      Col_Start     => Natural (Sloc_Start.Column),
                      Line_End      => 0,
                      Col_End       => 0,
                      Justification => Action.Justification,
                      Exempted_Name => To_Unbounded_String (Exempted_Name),
                      Detected      => 0),
                   Rule        => Rule,
                   SF          => SF,
                   Params      => Action.Params));
            end if;

         when Exempt_Off       =>
            --  If there are no parameters provided, just verify that
            --  the name is exempted, if so close the exemption.
            if not Has_Params then
               if Is_Exempted (Collector, Id) then
                  Turn_Off_Exemption (Collector, Id, Sloc_End, SF);
               else
                  Exempt_Diag
                    ("rule or instance "
                     & Exempted_Name
                     & " is not in "
                     & "exempted state");
               end if;

            else
               --  If there are some parameters, check that the name
               --  is exempted with the same parameter and close the
               --  exemption.
               Exempted_At :=
                 Exemption_Section_With_Params (Collector, Id, Action.Params);

               if Has_Element (Exempted_At) then
                  Turn_Off_Parametrized_Exemption
                    (Collector, Id, Exempted_At, Sloc_End, SF);
               else
                  Exempt_Diag
                    ("rule or instance "
                     & Exempted_Name
                     & " is not in "
                     & "exempted state");
               end if;
            end if;

         when Not_An_Exemption =>
            pragma Assert (False);
      end case;
   end Process_Exempt_Action;

   -------------------------------
   -- Process_Exemption_Comment --
   -------------------------------

   procedure Process_Exemption_Comment
     (Collector : in out Diagnostic_Collector;
      El        : LAL.Common.Token_Reference;
      Unit      : LAL.Analysis.Analysis_Unit)
   is
      Text    : constant String := Image (LAL.Common.Text (El));
      SF      : constant SF_Id := File_Find (Unit.Get_Filename);
      Matches : Match_Array (0 .. 4);
   begin
      --  Early out to not try and match comments that don't have the
      --  expected syntax.
      if Text'Last < 4 or else Text (1 .. 4) /= "--##" then
         return;
      end if;

      if Mode = Gnatkp_Mode then
         Match (Match_Kp_Exempt_Comment, Text, Matches);
      else
         Match (Match_Rule_Exempt_Comment, Text, Matches);
      end if;

      if Matches (0) = No_Match then
         --  We don't issue a warning here, because, it's possible
         --  (however unlikely) that some people are using the "--##"
         --  syntax for other things.
         return;
      end if;

      declare
         Is_Line : constant Boolean := Matches (1) /= No_Match;
         State   : String renames Text (Matches (2).First .. Matches (2).Last);
         Rule    : constant String :=
           To_XString (Text (Matches (3).First .. Matches (3).Last))
             .Trim
             .To_String;

         Just : constant String :=
           (if Matches (4) = No_Match
            then ""
            else
              To_XString (Text (Matches (4).First .. Matches (4).Last))
                .Trim
                .To_String);

         use LCO;
      begin
         if Is_Line then
            if State = "on" then
               Store_Diagnostic
                 (Collector,
                  Full_File_Name => Unit.Get_Filename,
                  Sloc           =>
                    Langkit_Support.Slocs.Start_Sloc (Sloc_Range (Data (El))),
                  Message        =>
                    "State should be ""off"" for line exemption",
                  Kind           => Exemption_Warning,
                  SF             => SF);
            end if;

            declare
               Sloc : constant Source_Location_Range :=
                 (Sloc_Range (Data (El)) with delta Start_Column => 1);
            begin
               --  In order, emit one action to turn the exempt on,
               --  and the other to turn the exempt off, on the same
               --  line. ``Process_Exempt_Action`` will take the start
               --  sloc for the exempt on, and the end sloc for the
               --  exempt off.
               for Exempt_Kind in Exempt_On .. Exempt_Off loop
                  Process_Exempt_Action
                    (Collector,
                     (Exempt_Kind,
                      To_Unbounded_String (Rule),
                      Params              => <>,
                      Justification       => To_Unbounded_String (Just),
                      Check_Justification => False,
                      Sloc_Range          => Sloc,
                      Unit                => Unit));
               end loop;
            end;
         else
            Process_Exempt_Action
              (Collector,
               ((if State = "on"
                 then Exempt_Off
                 elsif State = "off"
                 then Exempt_On
                 else raise Constraint_Error with "should not happen"),
                To_Unbounded_String (Rule),
                Params              => <>,
                Justification       => To_Unbounded_String (Just),

                --  With this syntax, we don't want to enforce the
                --  justification rules that we have for pragmas.
                Check_Justification => False,
                Sloc_Range          => Sloc_Range (Data (El)),
                Unit                => Unit));
         end if;
      end;

   end Process_Exemption_Comment;

   ------------------------------
   -- Process_Exemption_Pragma --
   ------------------------------

   procedure Process_Exemption_Pragma
     (Collector : in out Diagnostic_Collector; El : LAL.Analysis.Pragma_Node)
   is
      Pragma_Args : constant LAL.Analysis.Base_Assoc_List := El.F_Args;
      SF          : constant SF_Id := File_Find (El.Unit.Get_Filename);
      Action      : Exempt_Action;

      use Lkql_Checker.Rules.Exemption_Parameters;
      use LCO;
   begin
      Action.Unit := El.Unit;
      Action.Sloc_Range := El.Sloc_Range;

      --  First, analyze the pragma format:
      --
      --  1. Check that we have at least three parameters
      if Pragma_Args.Children_Count < 3 then
         Store_Diagnostic
           (Collector,
            Full_File_Name => El.Unit.Get_Filename,
            Sloc           => Start_Sloc (El.Sloc_Range),
            Message        => "too few parameters for exemption, ignored",
            Kind           => Exemption_Warning,
            SF             => SF);
         return;
      end if;

      --  2. Second parameter should be either "Exempt_On" or
      --     "Exempt_Off"
      Action.Exemption_Control :=
        Get_Exemption_Kind (Pragma_Args.List_Child (2).P_Assoc_Expr.Text);

      --  3. Third parameter should be the name of some existing rule,
      --     may be, with parameter names, but the latter is allowed
      --     only if fine-tuned exemptions is allowed for the rule, and
      --     if parameter names make sense for the given rule:
      declare
         Matches : Match_Array (0 .. 2);
         Text    : constant String :=
           Image (Pragma_Args.List_Child (3).P_Assoc_Expr.Text);
      begin
         Match (Match_Rule_Name, Text, Matches);

         pragma Assert (Matches (0) /= No_Match, "failed parsing rule name");

         Action.Exempted_Name :=
           To_Unbounded_String (Text (Matches (1).First .. Matches (1).Last));

         if Matches (2) /= No_Match then
            --  NOTE: This is sub-optimal, we still need to parse the
            --  rule kind here, because parameters parsing depends on
            --  the rule.
            Action.Params :=
              Parse_Exempt_Parameters
                (Collector,
                 Get_Rule (To_String (Action.Exempted_Name)),
                 Text (Matches (2).First .. Matches (2).Last),
                 SF,
                 Sloc_Image (Start_Sloc (El.Sloc_Range)));

            if Is_Empty (Action.Params) then
               Store_Diagnostic
                 (Collector,
                  Full_File_Name => El.Unit.Get_Filename,
                  Sloc           => Start_Sloc (El.Sloc_Range),
                  Message        => "Invalid parameters",
                  Kind           => Exemption_Warning,
                  SF             => SF);
            end if;
         end if;
      end;

      --  4. Fourth parameter, if present, should be a string.
      if Pragma_Args.Children_Count >= 4 then
         --  Evaluate the static string expression of the fourth
         --  parameter via Libadalang.Expr_Eval.
         begin
            declare
               use Libadalang.Expr_Eval;
               Eval_Res : constant Eval_Result :=
                 Expr_Eval (Pragma_Args.List_Child (4).P_Assoc_Expr);
            begin
               Action.Justification :=
                 To_Unbounded_String (Image (To_Text (As_String (Eval_Res))));
            end;
         exception
            when Property_Error =>
               --  If we couldn't evaluate the expression as a string,
               --  a property_error will have been raised. In that
               --  case, emit a diagnostic.
               Store_Diagnostic
                 (Collector,
                  Full_File_Name => El.Unit.Get_Filename,
                  Sloc           => Start_Sloc (El.Sloc_Range),
                  Message        =>
                    "exemption justification should be a string",
                  Kind           => Exemption_Warning,
                  SF             => SF);

               --  We already notified the user of the problem, make
               --  sure we won't emit another warning due to the
               --  absence of justification.
               Action.Check_Justification := False;
         end;
      end if;

      if Pragma_Args.Children_Count > 4 then
         Store_Diagnostic
           (Collector,
            Full_File_Name => El.Unit.Get_Filename,
            Sloc           => Start_Sloc (El.Sloc_Range),
            Message        => "rule exemption may have at most 4 parameters",
            Kind           => Exemption_Warning,
            SF             => SF);
      end if;

      --  Process the resulting exempt action
      Process_Exempt_Action (Collector, Action);

   end Process_Exemption_Pragma;

   ----------------------------------
   -- Process_Postponed_Exemptions --
   ----------------------------------

   procedure Process_Postponed_Exemptions
     (Collector : in out Diagnostic_Collector)
   is
      Current_Exemption : Exemption_Id;

      procedure Map_Diagnostic (Position : Error_Messages_Storage.Cursor);
      --  Maps the diagnostic pointed by the argument onto stored
      --  information about exemption sections. If the diagnostic
      --  points to some place inside some exemption section, and the
      --  diagnostic is not exempted, then the diagnostic is exempted
      --  by adding the justification from the exemption section, and
      --  the corresponding exemption violation is counted for the
      --  given exemption section

      procedure Map_Diagnostic (Position : Error_Messages_Storage.Cursor) is
         Diag        : Diagnostic := Error_Messages_Storage.Element (Position);
         Diag_Line   : constant Positive := Positive (Diag.Sloc.Line);
         Diag_Column : constant Positive := Positive (Diag.Sloc.Column);
         SF          : constant SF_Id := Diag.SF;
         R_Name      : constant String :=
           (if Diag.Kind = Rule_Violation then Rule_Name (Diag.Rule) else "");
         I_Name      : constant String :=
           (if Diag.Instance /= null and then Diag.Instance.Is_Alias
            then Instance_Name (Diag.Instance.all)
            else "");
         Is_Exempted : Boolean;
      begin
         if Diag.Kind /= Rule_Violation then
            return;
         end if;

         if Diag.Justification /= Null_Unbounded_String then
            --  Some diagnostics may be already exempted
            return;
         end if;

         if not Present (SF) then
            --  This is the case when the diagnostic is generated for
            --  expanded generic, and the generic itself is not an
            --  input.
            return;
         end if;

         --  First, check for non-parametric exemptions: try to map
         --  the diagnostic onto non-parametric exemption sections.
         --  there is one.
         Map_On_Postponed_Check_Exemption
           (Collector,
            In_File       => SF,
            For_Name      => R_Name,
            For_Line      => Diag_Line,
            Is_Exempted   => Is_Exempted,
            Justification => Diag.Justification);

         if not Is_Exempted and then I_Name /= "" then
            Map_On_Postponed_Check_Exemption
              (Collector,
               In_File       => SF,
               For_Name      => I_Name,
               For_Line      => Diag_Line,
               Is_Exempted   => Is_Exempted,
               Justification => Diag.Justification);
         end if;

         --  Then, check for parametric exemptions
         if not Is_Exempted and then Allows_Parametrized_Exemption (Diag.Rule)
         then
            Diag.Justification :=
              Get_Param_Justification
                (Collector,
                 Name => R_Name,
                 Rule => Diag.Rule,
                 Diag => To_String (Diag.Text),
                 SF   => SF,
                 Line => Diag_Line,
                 Col  => Diag_Column);
            Is_Exempted := Diag.Justification /= Null_Unbounded_String;

            if not Is_Exempted
              and then I_Name /= ""
              and then Allows_Parametrized_Exemption (Diag.Rule)
            then
               Diag.Justification :=
                 Get_Param_Justification
                   (Collector,
                    Name => I_Name,
                    Rule => Diag.Rule,
                    Diag => To_String (Diag.Text),
                    SF   => SF,
                    Line => Diag_Line,
                    Col  => Diag_Column);
               Is_Exempted := Diag.Justification /= Null_Unbounded_String;
            end if;
         end if;

         if Is_Exempted then
            Collector.All_Error_Messages.Replace_Element (Position, Diag);
         end if;
      end Map_Diagnostic;

      --  Start of processing for Process_Postponed_Exemptions

   begin
      Collector.All_Error_Messages.Iterate (Map_Diagnostic'Access);

      --  Now, iterate through the stored exemption and generate
      --  exemption warnings for those of them for which no exempted
      --  diagnostics are found.

      for SF in First_SF_Id .. Last_Argument_Source loop
         --  Non-parametric exemption
         for Cursor in Collector.Postponed_Exemption_Sections.Iterate loop
            Current_Exemption := Postponed_Exemption_Sections_Map.Key (Cursor);

            for Section of
              Collector.Postponed_Exemption_Sections.Reference
                (Current_Exemption) (SF)
            loop
               if Section.Detected = 0 then
                  Store_Diagnostic
                    (Collector,
                     Full_File_Name => File_Name (SF),
                     Sloc           =>
                       (Line_Number (Section.Line_End),
                        Column_Number (Section.Col_End)),
                     Message        =>
                       "no detection for "
                       & To_String (Section.Exempted_Name)
                       & " in exemption section starting at line"
                       & Section.Line_Start'Img,
                     Kind           => Exemption_Warning,
                     SF             => SF);
               end if;
            end loop;
         end loop;

         --  Parametric exemptions
         for Cursor in Collector.Postponed_Param_Exempt_Sections.Iterate loop
            Current_Exemption :=
              Per_Rule_Postponed_Param_Exemp_Map.Key (Cursor);

            for Section of
              Collector.Postponed_Param_Exempt_Sections (Current_Exemption)
                (SF)
            loop
               if Section.Exempt_Info.Detected = 0 then
                  Store_Diagnostic
                    (Collector,
                     Full_File_Name => File_Name (SF),
                     Sloc           =>
                       (Line_Number (Section.Exempt_Info.Line_End),
                        Column_Number (Section.Exempt_Info.Col_End)),
                     Message        =>
                       "no detection for '"
                       & To_String (Section.Exempt_Info.Exempted_Name)
                       & ": "
                       & Params_Img (Section.Params, Section.Rule)
                       & "' in exemption section starting at line"
                       & Section.Exempt_Info.Line_Start'Img,
                     Kind           => Exemption_Warning,
                     SF             => SF);
               end if;
            end loop;
         end loop;
      end loop;
   end Process_Postponed_Exemptions;

   --------------------
   -- Rule_Parameter --
   --------------------

   function Rule_Parameter (Diag : String; Rule : Rule_Id) return String is
   begin
      if Rule = Restrictions_Id then
         return Restriction_Rule_Parameter (Diag);
      elsif Rule = Warnings_Id then
         return Warning_Rule_Parameter (Diag);
      elsif Rule = Style_Checks_Id then
         return Style_Rule_Parameter (Diag);
      else
         return All_Rules (Rule).Rule_Param_From_Diag (Diag);
      end if;
   end Rule_Parameter;

   ------------------------
   -- Turn_Off_Exemption --
   ------------------------

   procedure Turn_Off_Exemption
     (Collector    : in out Diagnostic_Collector;
      Id           : Exemption_Id;
      Closing_Sloc : Source_Location;
      SF           : SF_Id) is
   begin
      --  Set the exemption closing source location
      Collector.Exemption_Sections (Id).Line_End :=
        Natural (Closing_Sloc.Line);
      Collector.Exemption_Sections (Id).Col_End :=
        Natural (Closing_Sloc.Column);

      --  If the map of postponed exemptions doesn't contain exemptions
      --  related to ``Id``, create a new array associated to this rule.
      if not Collector.Postponed_Exemption_Sections.Contains (Id) then
         Collector.Postponed_Exemption_Sections.Insert
           (Id, (First_SF_Id .. Last_Argument_Source => <>));
      end if;

      --  Add the exemption to the postponed exemption sections
      Collector.Postponed_Exemption_Sections.Reference (Id) (SF).Append
        (Collector.Exemption_Sections (Id));

      --  Remove the exemption from the map
      Collector.Exemption_Sections.Delete (Id);
   end Turn_Off_Exemption;

   -------------------------------------
   -- Turn_Off_Parametrized_Exemption --
   -------------------------------------

   procedure Turn_Off_Parametrized_Exemption
     (Collector    : in out Diagnostic_Collector;
      Id           : Exemption_Id;
      Exempted_At  : in out Parametrized_Exemption_Sections.Cursor;
      Closing_Sloc : Source_Location;
      SF           : SF_Id)
   is
      New_Section : Parametrized_Exemption_Info;
   begin
      --  Set the exemption section closing source location
      New_Section := Parametrized_Exemption_Sections.Element (Exempted_At);
      New_Section.Exempt_Info.Line_End := Natural (Closing_Sloc.Line);
      New_Section.Exempt_Info.Col_End := Natural (Closing_Sloc.Column);

      --  Create a postponed param exemption array for the rule if it
      --  does not exist.
      if not Collector.Postponed_Param_Exempt_Sections.Contains (Id) then
         Collector.Postponed_Param_Exempt_Sections.Insert
           (Id,
            new Per_Source_Postponed_Param_Exemp
                  (First_SF_Id .. Last_Argument_Source));
      end if;

      --  Insert the exemption in the postponed list for later
      --  handling, then remove the original exemption from the map.
      Collector.Postponed_Param_Exempt_Sections (Id) (SF).Insert (New_Section);
      Collector.Rule_Param_Exempt_Sections (Id).Delete (Exempted_At);
   end Turn_Off_Parametrized_Exemption;

end Lkql_Checker.Diagnostics.Exemptions;
