--
--  Copyright (C) 2005-2026, AdaCore
--  SPDX-License-Identifier: GPL-3.0-or-later
--

with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with GNAT.Regexp;

with GNATCOLL.JSON; use GNATCOLL.JSON;

with Liblkqllang.Analysis;
with Liblktlang.Analysis;

--  A diagnostic is composed of a collection of individual rule commands

package Rule_Commands is

   package Lkql renames Liblkqllang.Analysis;
   package Lkt renames Liblktlang.Analysis;

   Rule_Error : exception;

   type Rule_Argument is record
      Name : Unbounded_String;
      --  Name of the argument

      Value : Unbounded_String;
      --  Value of the argument, as a string.
   end record;

   package Rule_Argument_Vectors is new
     Ada.Containers.Vectors (Positive, Rule_Argument);

   type Rule_Param_Kind is
     (No_Param,
      One_Integer,
      One_Boolean,
      One_String,
      One_Array,
      One_Integer_Or_Booleans,
      Custom);
   --  Specifies how parameters are handled by the rule

   type Remediation_Levels is (Trivial, Easy, Medium, Major, High, Complex);
   --  Difficulty to address the rule violation.

   type Regexp_Access is access all GNAT.Regexp.Regexp;

   type Rule_Parameter is record
      Name        : Unbounded_String;
      Has_Default : Boolean;
   end record;

   package Rule_Parameter_Vectors is new
     Ada.Containers.Indefinite_Vectors (Positive, Rule_Parameter);
   subtype Rule_Parameters is Rule_Parameter_Vectors.Vector;

   type Rule_Command is tagged record
      Name : Unbounded_String;
      --  Name of the Rule

      Message : Unbounded_String;
      --  Message for violations of the rule.

      Help : Unbounded_String;
      --  Short help message associated with the rule.
      --  Defaults to Message if not specified.

      Category : Unbounded_String;
      --  Category of this rule, if relevant

      Subcategory : Unbounded_String;
      --  Subcategory of this rule, if relevant

      Param_Kind : Rule_Param_Kind;
      --  Category of parameters.

      Parameters : Rule_Parameters;
      --  List of formal parameters for this rule.

      Remediation_Level : Remediation_Levels;
      --  Remediation level to compute technical debt.

      Parametric_Exemption : Boolean;

      Impact : Regexp_Access;
      --  For a KP detector, regexp to match relevant releases impacted, if
      --  any. Ignored if null.

      Target : Regexp_Access;
      --  For a KP detector, regexp to match relevant target triplets impacted,
      --  if any. Ignored if null.

      Target_String : Unbounded_String;
      --  Raw target pattern string (e.g. "x86_64-*"), set when Target is
      --  non-null. Used for diagnostic messages.
   end record;

   function Create_Rule_Command
     (Lkql_File_Path : String;
      Ctx            : Lkql.Analysis_Context;
      Impacts        : JSON_Value;
      Rc             : out Rule_Command) return Boolean;
   --  Create a Rule_Command value with the given name and arguments and
   --  store it in ``Rc``. Return ``True`` if this succeeded, ie. the file
   --  corresponds to a (LKQL version 1) rule file, ``False`` otherwise.

   function Create_Rule_Command
     (Lkql_File_Path : String;
      Ctx            : Lkt.Analysis_Context;
      Impacts        : JSON_Value;
      Rc             : out Rule_Command) return Boolean;
   --  Create a Rule_Command value with the given name and arguments and
   --  store it in ``Rc``. Return ``True`` if this succeeded, ie. the file
   --  corresponds to a (LKQL version 2) rule file, ``False`` otherwise.

end Rule_Commands;
