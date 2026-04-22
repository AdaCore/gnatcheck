--
--  Copyright (C) 2005-2026, AdaCore
--  SPDX-License-Identifier: GPL-3.0-or-later
--

--  This package provides the rule exemption mechanism for GNATcheck.

with Libadalang.Analysis;
with Libadalang.Common;

package Lkql_Checker.Diagnostics.Exemptions is

   package LAL renames Libadalang;

   --------------------------
   -- Diagnostics matching --
   --------------------------

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
   -- Exemption mechanism --
   -------------------------

   function Is_Exemption_Pragma (El : LAL.Analysis.Pragma_Node) return Boolean;
   --  Checks if the argument Element is the Annotate or GNAT_Annotate
   --  pragma with the first parameter equal to the current checker mode.

   procedure Process_Exemption_Pragma
     (Collector : in out Diagnostic_Collector; El : LAL.Analysis.Pragma_Node);
   --  Analyses the argument element and stores the information about
   --  exemption section. In most of the cases it is equivalent to
   --  turning the rule into exempted state, but for the following rule
   --  categories: compiler checks, post-processing is needed after all
   --  rule checking and processing is completed.

   procedure Process_Exemption_Comment
     (Collector : in out Diagnostic_Collector;
      El        : LAL.Common.Token_Reference;
      Unit      : LAL.Analysis.Analysis_Unit);
   --  Process any comment from a source being analyzed. If it is an
   --  exemption comment, process it.
   --
   --  The logic is the same as ``Process_Exemption_Pragma``, only the
   --  syntax differs.

   procedure Check_Unclosed_Rule_Exemptions
     (Collector : in out Diagnostic_Collector;
      SF        : SF_Id;
      Unit      : LAL.Analysis.Analysis_Unit);
   --  Is supposed to be called in the very end of processing of the
   --  source corresponding to SF. Checks if there exist some exempted
   --  rules. For each such rule, a warning is issued and exemption is
   --  turned OFF. Unit parameter is used to compute the end of
   --  non-closed exemption sections for compiler checks, if any.

   procedure Process_Postponed_Exemptions
     (Collector : in out Diagnostic_Collector);
   --  Iterate through the stored diagnostics and apply postponed
   --  exemptions to diagnostics.

end Lkql_Checker.Diagnostics.Exemptions;
