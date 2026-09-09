--
--  Copyright (C) 2005-2026, AdaCore
--  SPDX-License-Identifier: GPL-3.0-or-later
--

with Ada.Characters.Conversions;      use Ada.Characters.Conversions;
with Ada.Strings.Wide_Wide_Unbounded; use Ada.Strings.Wide_Wide_Unbounded;

with Lkql_Checker.String_Utilities;

with Liblkqllang.Common;
with Liblkqllang.Generic_API.Introspection;
with Liblkqllang.Iterators;

with Liblktlang.Common;
with Liblktlang.Generic_API.Introspection;
with Liblktlang.Iterators;

package body Rule_Commands is

   type Param_Type is
     (Bool_Param, Int_Param, String_Param, List_Param, Any_Param);
   --  The type of a rule parameter.

   package Param_Type_Vectors is new
     Ada.Containers.Vectors (Positive, Param_Type);
   subtype Param_Type_Vector is Param_Type_Vectors.Vector;

   function Augment_With_Majors (Impact_Str : String) return String;
   --  Return Impact_Str augmented with the major-version prefix of each entry,
   --  so that a bare major version (e.g. "20") also matches in the compiled
   --  regexp (e.g. "20.1" or "20.*").

   function Get_Param_Type (Param : Lkql.Parameter_Decl) return Param_Type;
   --  Get the type of a LKQL V1 rule parameter according to its type
   --  annotation and default value.

   function Get_Param_Type (Param : Lkt.Fun_Param_Decl) return Param_Type;
   --  Get the type of a LKQL V2 rule parameter according to its type
   --  annotation and default value.

   function Find_Param_Kind
     (Param_Types : Param_Type_Vector) return Rule_Param_Kind;
   --  Return the rule parameter kind given the function's parameter types.

   procedure Set_Impact_Pattern
     (Impacts         : JSON_Value;
      Rule_Name       : Text_Type;
      Annotation_Kind : Text_Type;
      Impact          : out Regexp_Access);
   --  Looks up the impact pattern for the given rule name. Assign it to
   --  Impact if found, otherwise raise an exception.

   procedure Set_Target_Pattern
     (Target_Text     : Text_Type;
      Annotation_Kind : Text_Type;
      Target          : out Regexp_Access;
      Target_Str      : out Unbounded_Wide_Wide_String);
   --  Extract the given "target" pattern to an actual regexp object, or raise
   --  an exception if the pattern failed to parse.

   procedure Set_Remediation_Level
     (Remediation_Text  : Text_Type;
      Annotation_Kind   : Text_Type;
      Remediation_Level : out Remediation_Levels);
   --  Parse the remediation level from the given text into an actual
   --  Remediation_Levels value. Raise an exception if that was unsuccessful.

   -------------------------
   -- Augment_With_Majors --
   -------------------------

   function Augment_With_Majors (Impact_Str : String) return String is
      use Lkql_Checker.String_Utilities;
      Entries : constant String_Vector := Split (Impact_Str, ',');
      Result  : String_Vector := Entries;
   begin
      for E of Entries loop
         for I in E'Range loop
            if E (I) = '.' then
               Result.Append (E (E'First .. I - 1));
               exit;
            end if;
         end loop;
      end loop;
      return Join (Result, ",");
   end Augment_With_Majors;

   --------------------
   -- Get_Param_Type --
   --------------------

   function Get_Param_Type (Param : Lkql.Parameter_Decl) return Param_Type is
      package LCO renames Liblkqllang.Common;

      Type_Ann  : constant Lkql.Identifier := Param.F_Type_Annotation;
      Type_Name : constant Text_Type :=
        (if Type_Ann.Is_Null then "any" else Type_Ann.Text);
   begin
      if Type_Name = "bool" then
         return Bool_Param;
      elsif Type_Name = "int" then
         return Int_Param;
      elsif Type_Name = "string" then
         return String_Param;
      elsif Type_Name = "list" then
         return List_Param;
      elsif not Param.F_Default_Expr.Is_Null then
         --  In the case where there is not type annotation, try to guess the
         --  parameter type from the default value.
         case Param.F_Default_Expr.Kind is
            when LCO.Lkql_Bool_Literal    =>
               return Bool_Param;

            when LCO.Lkql_Integer_Literal =>
               return Int_Param;

            when LCO.Lkql_String_Literal  =>
               return String_Param;

            when LCO.Lkql_List_Literal    =>
               return List_Param;

            when others                   =>
               return Any_Param;
         end case;
      else
         return Any_Param;
      end if;
   end Get_Param_Type;

   --------------------
   -- Get_Param_Type --
   --------------------

   function Get_Param_Type (Param : Lkt.Fun_Param_Decl) return Param_Type is
      package LCO renames Liblktlang.Common;

      Type_Name : constant Text_Type := Param.F_Decl_Type.Text;
   begin
      if Type_Name = "Bool" then
         return Bool_Param;
      elsif Type_Name = "Int" then
         return Int_Param;
      elsif Type_Name = "String" then
         return String_Param;
      elsif Type_Name'Length > 5
        and then Type_Name (Type_Name'First .. Type_Name'First + 4) = "List["
      then
         return List_Param;
      elsif Type_Name = "Any" and then not Param.F_Default_Val.Is_Null then
         --  In the case where there is a dummy type annotation (e.g. produced
         --  by the auto migration tool), try to guess the parameter type from
         --  the default value.
         case Param.F_Default_Val.Kind is
            when LCO.Lkt_Id_Range      =>
               if Param.F_Default_Val.Text in "true" | "false" then
                  return Bool_Param;
               end if;

            when LCO.Lkt_Num_Lit       =>
               return Int_Param;

            when LCO.Lkt_String_Lit    =>
               return String_Param;

            when LCO.Lkt_Array_Literal =>
               return List_Param;

            when others                =>
               null;
         end case;
      end if;
      return Any_Param;
   end Get_Param_Type;

   ---------------------
   -- Find_Param_Kind --
   ---------------------

   function Find_Param_Kind
     (Param_Types : Param_Type_Vector) return Rule_Param_Kind is
   begin
      if Param_Types.Last_Index = 1 then
         return No_Param;
      elsif Param_Types.Last_Index = 2 then
         case Param_Types (2) is
            when Int_Param    =>
               return One_Integer;

            when Bool_Param   =>
               return One_Boolean;

            when String_Param =>
               return One_String;

            when List_Param   =>
               return One_Array;

            when others       =>
               null;
         end case;
      else
         if Param_Types.Last_Index <= 10
           and then Param_Types (2) in Int_Param | Bool_Param
         then
            for J in 3 .. Param_Types.Last_Index loop
               if Param_Types (J) /= Bool_Param then
                  return Custom;
               end if;
            end loop;

            return One_Integer_Or_Booleans;
         end if;
      end if;

      return Custom;
   end Find_Param_Kind;

   ------------------------
   -- Set_Impact_Pattern --
   ------------------------

   procedure Set_Impact_Pattern
     (Impacts         : JSON_Value;
      Rule_Name       : Text_Type;
      Annotation_Kind : Text_Type;
      Impact          : out Regexp_Access)
   is
      use GNAT.Regexp;

      Impact_Value : constant JSON_Value :=
        Impacts.Get (To_UTF8 (To_Lower (Rule_Name)));
   begin
      if Impact_Value /= JSON_Null then
         Impact :=
           new Regexp'
             (Compile
                ("{" & Augment_With_Majors (Impact_Value.Get) & "}",
                 Glob           => True,
                 Case_Sensitive => False));
      end if;
   exception
      when others =>
         raise Rule_Error
           with "invalid impact entry for " & To_String (Annotation_Kind);
   end Set_Impact_Pattern;

   ------------------------
   -- Set_Target_Pattern --
   ------------------------

   procedure Set_Target_Pattern
     (Target_Text     : Text_Type;
      Annotation_Kind : Text_Type;
      Target          : out Regexp_Access;
      Target_Str      : out Unbounded_Wide_Wide_String)
   is
      use GNAT.Regexp;

      Str            : constant String := To_String (Target_Text);
      Target_Pattern : constant String := Str (Str'First + 1 .. Str'Last - 1);
   begin
      Target :=
        new Regexp'
          (Compile
             ("{" & Target_Pattern & "}",
              Glob           => True,
              Case_Sensitive => False));
      Target_Str :=
        To_Unbounded_Wide_Wide_String (To_Wide_Wide_String (Target_Pattern));

   exception
      when others =>
         raise Rule_Error
           with "invalid argument for @" & To_String (Annotation_Kind);
   end Set_Target_Pattern;

   ---------------------------
   -- Set_Remediation_Level --
   ---------------------------

   procedure Set_Remediation_Level
     (Remediation_Text  : Text_Type;
      Annotation_Kind   : Text_Type;
      Remediation_Level : out Remediation_Levels)
   is
      Str : constant String := To_String (Remediation_Text);
   begin
      Remediation_Level :=
        Remediation_Levels'Value (Str (Str'First + 1 .. Str'Last - 1));
   exception
      when others =>
         raise Rule_Error
           with "invalid argument for @" & To_String (Annotation_Kind);
   end Set_Remediation_Level;

   -------------------------
   -- Create_Rule_Command --
   -------------------------

   function Create_Rule_Command
     (Lkql_File_Path : String;
      Ctx            : Lkql.Analysis_Context;
      Impacts        : JSON_Value;
      Rc             : out Rule_Command) return Boolean
   is
      use Liblkqllang.Common;
      use Liblkqllang.Iterators;
      use Liblkqllang.Generic_API.Introspection;

      Root : constant Lkql.Lkql_Node :=
        Ctx.Get_From_File (Lkql_File_Path).Root;

      Check_Annotation : constant Lkql.Decl_Annotation :=
        Find_First
          (Root,
           Kind_Is (Lkql_Decl_Annotation)
           and Child_With
                 (Member_Refs.Decl_Annotation_F_Name,
                  Text_Is ("check") or Text_Is ("unit_check")))
          .As_Decl_Annotation;
   begin
      if Check_Annotation.Is_Null
        or else Check_Annotation.F_Name.Text not in "check" | "unit_check"
      then
         return False;
      end if;

      declare
         Fn                       : constant Lkql.Fun_Decl :=
           Check_Annotation.Parent.As_Fun_Decl;
         Rule_Name_Arg            : constant Lkql.Arg :=
           Check_Annotation.P_Arg_With_Name (To_Unbounded_Text ("rule_name"));
         Msg_Arg                  : constant Lkql.Arg :=
           Check_Annotation.P_Arg_With_Name (To_Unbounded_Text ("message"));
         Help_Arg                 : constant Lkql.Arg :=
           Check_Annotation.P_Arg_With_Name (To_Unbounded_Text ("help"));
         Category_Arg             : constant Lkql.Arg :=
           Check_Annotation.P_Arg_With_Name (To_Unbounded_Text ("category"));
         Subcategory_Arg          : constant Lkql.Arg :=
           Check_Annotation.P_Arg_With_Name
             (To_Unbounded_Text ("subcategory"));
         Parametric_Exemption_Arg : constant Lkql.Arg :=
           Check_Annotation.P_Arg_With_Name
             (To_Unbounded_Text ("parametric_exemption"));
         Remediation_Arg          : constant Lkql.Arg :=
           Check_Annotation.P_Arg_With_Name
             (To_Unbounded_Text ("remediation"));
         Target_Arg               : constant Lkql.Arg :=
           Check_Annotation.P_Arg_With_Name (To_Unbounded_Text ("target"));
         Name                     : Unbounded_Text_Type;
         Msg                      : Unbounded_Text_Type;
         Help                     : Unbounded_Text_Type;
         Category                 : Unbounded_Text_Type;
         Subcategory              : Unbounded_Text_Type;
         Impact                   : Regexp_Access;
         Target                   : Regexp_Access;
         Target_Str               : Unbounded_Text_Type;
         Rule_Params              : Rule_Parameters;
         Remediation_Level        : Remediation_Levels := Medium;
         Parametric_Exemption     : Boolean := False;
         Fn_Name                  : constant Text_Type := Fn.F_Name.Text;
         Annotation_Kind          : constant Text_Type :=
           Check_Annotation.F_Name.Text;

         Param_Types : Param_Type_Vector;
         Param_Kind  : Rule_Param_Kind;

         procedure Check_String (Arg : Lkql.Arg);
         --  Check whether the argument is a string literal, raise Rule_Error
         --  if not.

         procedure Get_Text
           (Arg     : Lkql.Arg;
            Default : Unbounded_Text_Type;
            Text    : out Unbounded_Text_Type);
         --  Get text value from Arg and store result in Text. Defaults to
         --  Default if Arg is null.

         ------------------
         -- Check_String --
         ------------------

         procedure Check_String (Arg : Lkql.Arg) is
         begin
            if Arg.P_Expr.Kind /= Lkql_String_Literal then
               raise Rule_Error
                 with
                   "argument for @"
                   & To_String (Annotation_Kind)
                   & " must be a string literal";
            end if;
         end Check_String;

         --------------
         -- Get_Text --
         --------------

         procedure Get_Text
           (Arg     : Lkql.Arg;
            Default : Unbounded_Text_Type;
            Text    : out Unbounded_Text_Type) is
         begin
            if Arg.Is_Null then
               Text := Default;
            else
               --  Make sure that the message is a string literal

               Check_String (Arg);

               --  Store the literal, getting rid of the starting & end quotes

               Text := To_Unbounded_Text (Arg.P_Expr.As_String_Literal.Text);
               Delete (Text, Length (Text), Length (Text));
               Delete (Text, 1, 1);
            end if;
         end Get_Text;
      begin
         for P of Fn.F_Fun_Expr.F_Parameters loop
            Param_Types.Append (Get_Param_Type (P.As_Parameter_Decl));
         end loop;
         Param_Kind := Find_Param_Kind (Param_Types);

         --  Get the "follow_generic_instantiations" settings if the user
         --  specified one. By default it is false.

         if not Parametric_Exemption_Arg.Is_Null then
            Parametric_Exemption :=
              Parametric_Exemption_Arg.P_Expr.Text = "true";
         end if;

         Get_Text (Rule_Name_Arg, To_Unbounded_Text (Fn_Name), Name);
         Get_Text (Msg_Arg, Name, Msg);
         Get_Text (Help_Arg, Msg, Help);
         Get_Text (Category_Arg, To_Unbounded_Text ("Misc"), Category);
         Get_Text (Subcategory_Arg, To_Unbounded_Text (""), Subcategory);

         if Impacts /= JSON_Null then
            Set_Impact_Pattern (Impacts, Fn_Name, Annotation_Kind, Impact);
         end if;

         if not Target_Arg.Is_Null then
            Check_String (Target_Arg);
            Set_Target_Pattern
              (Target_Arg.P_Expr.As_String_Literal.Text,
               Annotation_Kind,
               Target,
               Target_Str);
         end if;

         if not Remediation_Arg.Is_Null then
            Check_String (Remediation_Arg);
            Set_Remediation_Level
              (Remediation_Arg.P_Expr.As_String_Literal.Text,
               Annotation_Kind,
               Remediation_Level);
         end if;

         for P of Fn.F_Fun_Expr.F_Parameters loop
            Rule_Params.Append
              (Rule_Parameter'
                 (Name        => To_Unbounded_Text (P.F_Param_Identifier.Text),
                  Has_Default => not P.F_Default_Expr.Is_Null));
         end loop;

         Rc :=
           Rule_Command'
             (Name                 => Name,
              Help                 => Help,
              Message              => Msg,
              Category             => Category,
              Subcategory          => Subcategory,
              Param_Kind           => Param_Kind,
              Parameters           => Rule_Params,
              Remediation_Level    => Remediation_Level,
              Parametric_Exemption => Parametric_Exemption,
              Impact               => Impact,
              Target               => Target,
              Target_String        => Target_Str);
         return True;
      end;
   end Create_Rule_Command;

   function Create_Rule_Command
     (Lkql_File_Path : String;
      Ctx            : Lkt.Analysis_Context;
      Impacts        : JSON_Value;
      Rc             : out Rule_Command) return Boolean
   is
      use Liblktlang.Common;
      use Liblktlang.Iterators;
      use Liblktlang.Generic_API.Introspection;

      Root : constant Lkt.Lkt_Node := Ctx.Get_From_File (Lkql_File_Path).Root;

      Check_Annotation : constant Lkt.Decl_Annotation :=
        Find_First
          (Root,
           Kind_Is (Lkt_Decl_Annotation)
           and Child_With
                 (Member_Refs.Decl_Annotation_F_Name,
                  Text_Is ("check") or Text_Is ("unit_check")))
          .As_Decl_Annotation;
   begin
      if Check_Annotation.Is_Null
        or else Check_Annotation.F_Name.Text not in "check" | "unit_check"
      then
         return False;
      end if;

      declare
         function Get_Annotation_Arg
           (Arg_Name : Text_Type) return Lkt.Argument;

         ------------------------
         -- Get_Annotation_Arg --
         ------------------------

         function Get_Annotation_Arg (Arg_Name : Text_Type) return Lkt.Argument
         is
         begin
            for Arg of Check_Annotation.F_Args.F_Args loop
               if To_Lower (Arg.F_Name.Text) = To_Lower (Arg_Name) then
                  return Arg.As_Argument;
               end if;
            end loop;
            return Lkt.No_Argument;
         end Get_Annotation_Arg;

         Fn                       : constant Lkt.Fun_Decl :=
           Check_Annotation.Parent.Parent.As_Full_Decl.F_Decl.As_Fun_Decl;
         Rule_Name_Arg            : constant Lkt.Argument :=
           Get_Annotation_Arg ("rule_name");
         Msg_Arg                  : constant Lkt.Argument :=
           Get_Annotation_Arg ("message");
         Help_Arg                 : constant Lkt.Argument :=
           Get_Annotation_Arg ("help");
         Category_Arg             : constant Lkt.Argument :=
           Get_Annotation_Arg ("category");
         Subcategory_Arg          : constant Lkt.Argument :=
           Get_Annotation_Arg ("subcategory");
         Parametric_Exemption_Arg : constant Lkt.Argument :=
           Get_Annotation_Arg ("parametric_exemption");
         Remediation_Arg          : constant Lkt.Argument :=
           Get_Annotation_Arg ("remediation");
         Target_Arg               : constant Lkt.Argument :=
           Get_Annotation_Arg ("target");
         Name                     : Unbounded_Text_Type;
         Msg                      : Unbounded_Text_Type;
         Help                     : Unbounded_Text_Type;
         Category                 : Unbounded_Text_Type;
         Subcategory              : Unbounded_Text_Type;
         Impact                   : Regexp_Access;
         Target                   : Regexp_Access;
         Target_Str               : Unbounded_Text_Type;
         Rule_Params              : Rule_Parameters;
         Remediation_Level        : Remediation_Levels := Medium;
         Parametric_Exemption     : Boolean := False;
         Fn_Name                  : constant Text_Type := Fn.F_Syn_Name.Text;
         Annotation_Kind          : constant Text_Type :=
           Check_Annotation.F_Name.Text;

         Param_Types : Param_Type_Vector;
         Param_Kind  : Rule_Param_Kind;

         procedure Check_String (Arg : Lkt.Argument);
         --  Check whether the argument is a string literal, raise Rule_Error
         --  if not.

         procedure Get_Text
           (Arg     : Lkt.Argument;
            Default : Unbounded_Text_Type;
            Text    : out Unbounded_Text_Type);
         --  Get text value from Arg and store result in Text. Defaults to
         --  Default if Arg is null.

         ------------------
         -- Check_String --
         ------------------

         procedure Check_String (Arg : Lkt.Argument) is
         begin
            if Arg.F_Value.Kind /= Lkt_Single_Line_String_Lit then
               raise Rule_Error
                 with
                   "argument for @"
                   & To_String (Annotation_Kind)
                   & " must be a string literal";
            end if;
         end Check_String;

         --------------
         -- Get_Text --
         --------------

         procedure Get_Text
           (Arg     : Lkt.Argument;
            Default : Unbounded_Text_Type;
            Text    : out Unbounded_Text_Type) is
         begin
            if Arg.Is_Null then
               Text := Default;
            else
               --  Make sure that the message is a string literal
               Check_String (Arg);

               --  Store the literal, getting rid of the starting & end quotes
               Text := To_Unbounded_Text (Arg.F_Value.As_String_Lit.Text);
               Delete (Text, Length (Text), Length (Text));
               Delete (Text, 1, 1);
            end if;
         end Get_Text;
      begin
         for P of Fn.F_Params loop
            Param_Types.Append (Get_Param_Type (P.As_Fun_Param_Decl));
         end loop;
         Param_Kind := Find_Param_Kind (Param_Types);

         --  Get the "follow_generic_instantiations" settings if the user
         --  specified one. By default it is false.

         if not Parametric_Exemption_Arg.Is_Null then
            Parametric_Exemption :=
              Parametric_Exemption_Arg.F_Value.Text = "true";
         end if;

         Get_Text (Rule_Name_Arg, To_Unbounded_Text (Fn_Name), Name);
         Get_Text (Msg_Arg, Name, Msg);
         Get_Text (Help_Arg, Msg, Help);
         Get_Text (Category_Arg, To_Unbounded_Text ("Misc"), Category);
         Get_Text (Subcategory_Arg, To_Unbounded_Text (""), Subcategory);
         if Impacts /= JSON_Null then
            Set_Impact_Pattern (Impacts, Fn_Name, Annotation_Kind, Impact);
         end if;

         if not Target_Arg.Is_Null then
            Check_String (Target_Arg);
            Set_Target_Pattern
              (Target_Arg.F_Value.As_String_Lit.Text,
               Annotation_Kind,
               Target,
               Target_Str);
         end if;

         if not Remediation_Arg.Is_Null then
            Check_String (Remediation_Arg);
            Set_Remediation_Level
              (Remediation_Arg.F_Value.As_String_Lit.Text,
               Annotation_Kind,
               Remediation_Level);
         end if;

         for P of Fn.F_Params loop
            Rule_Params.Append
              (Rule_Parameter'
                 (Name        => To_Unbounded_Text (P.F_Syn_Name.Text),
                  Has_Default => not P.F_Default_Val.Is_Null));
         end loop;

         Rc :=
           Rule_Command'
             (Name                 => Name,
              Help                 => Help,
              Message              => Msg,
              Category             => Category,
              Subcategory          => Subcategory,
              Param_Kind           => Param_Kind,
              Parameters           => Rule_Params,
              Remediation_Level    => Remediation_Level,
              Parametric_Exemption => Parametric_Exemption,
              Impact               => Impact,
              Target               => Target,
              Target_String        => Target_Str);
         return True;
      end;
   end Create_Rule_Command;

end Rule_Commands;
