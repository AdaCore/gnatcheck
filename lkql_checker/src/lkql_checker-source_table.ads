--
--  Copyright (C) 2005-2026, AdaCore
--  SPDX-License-Identifier: GPL-3.0-or-later
--

--  This package defines the source file table - the table containing the
--  information about the source files to be processed and the state of their
--  processing. Used by Several_Files_Driver.

with Ada.Containers.Indefinite_Ordered_Sets;

with Lkql_Checker.Diagnostics; use Lkql_Checker.Diagnostics;
with Lkql_Checker.Ids;         use Lkql_Checker.Ids;
with Lkql_Checker.Options;     use Lkql_Checker.Options;
with Lkql_Checker.Projects;    use Lkql_Checker.Projects;

with GNATCOLL.Projects; use GNATCOLL.Projects;

with Libadalang.Analysis; use Libadalang.Analysis;

package Lkql_Checker.Source_Table is

   type SF_Status is
     (Waiting,
      --  Waiting for processing

      Not_A_Legal_Source,
      --  The file does not contain compilable source

      Error_Detected,
      --  Some tool problem has been detected when processing this source
      --  so the results of processing may not be safe

      Processed
      --  The source file has been successfully processed
     );

   type SF_Info is new Integer;
   --  The type to be used for the integer values associate with each source in
   --  the source file table. The use of this value is client-specific

   function Present (SF : SF_Id) return Boolean;
   --  Checks that SF is not is equal to No_SF_Id

   function Get_File_Names_Case_Sensitive return Integer;
   pragma
     Import
       (C,
        Get_File_Names_Case_Sensitive,
        "__gnat_get_file_names_case_sensitive");
   File_Names_Case_Sensitive : constant Boolean :=
     Get_File_Names_Case_Sensitive /= 0;
   --  Set to indicate whether the operating system convention is for file
   --  names to be case sensitive (e.g., in Unix, set True), or non case
   --  sensitive (e.g., in Windows, set False). This code is taken as is from
   --  the GNAT Osint package to avoid dependency on Osint

   function File_Find
     (SF_Name        : String;
      Use_Short_Name : Boolean := False;
      Case_Sensitive : Boolean := File_Names_Case_Sensitive) return SF_Id;
   --  Returns the Id of the file with name SF_Name stored in the files
   --  table. Returns No_SF_Id if the table does not contain such a file.
   --  if Use_Short_Name parameter is True, the short file name is used to
   --  locate the file; if the argument contains a directory information it is
   --  stripped out. Otherwise this function tries to locate the name with the
   --  full normalized name equal to SF_Name.
   --  If Case_Sensitive is False, then this function first looks for the
   --  SF_Name using the original casing of SF_Name and files stored in the
   --  Source Table, and if it cannot locate the file, it repeats the search
   --  with all the path/file names converted to lower case.

   procedure Store_Sources_To_Process (Fname : String);
   --  Fname is stored in an internal database as the name of the file to be
   --  processed by the tool. No check is made if Fname denotes an existing
   --  file.

   procedure Read_Args_From_Temp_Storage
     (Duplication_Report : Boolean;
      Arg_Project        : Arg_Project_Type;
      Status             : SF_Status := Waiting);
   --  Reads argument files from temporary storage (where they are placed by
   --  Store_Sources_To_Process/Store_Args_From_File routine(s)). Uses
   --  Add_Source_To_Process to read each file, so the check if a file exists
   --  is performed on the base of the source search path
   --  (ASIS_UL.Compiler_Options.Source_Search_Path) or the project file that
   --  is a tool argument. This procedure calls Add_Source_To_Process for each
   --  file to do the existence test and to store source in the source table.
   --  The temporary storage is cleaned up.
   --
   --  The Duplication_Report parameter has the same meaning as for
   --  Add_Source_To_Process.
   --
   --  If the actual for Arg_Project denotes a project specified as a tool
   --  parameter then this procedure tries to store all the subunits *after*
   --  the units that are enclosing bodies for these subunits. This is needed
   --  to make sure that subunits will be processed on the base of the trees
   --  created for enclosing bodies, because only in this case the tree
   --  representing a subunit is attributed properly.

   procedure Read_Args_From_File (Par_File_Name : String);
   --  Reads argument files from the file. Stores the file names in the
   --  temporary storage as Store_Sources_To_Process does. This procedure
   --  assumes that the file named by Par_File_Name contains argument file
   --  names, one per line.

   procedure Temp_Storage_Iterate
     (Action : not null access procedure (File_Name : String));
   --  Call Action for each File_Name in the temporary file storage

   function Last_Source return SF_Id;
   --  Returns the Id of the last source stored in the source table. Returns
   --  No_SF_Id if there is no source file stored

   function Total_Sources_To_Process return Natural;
   --  Returns the number of the arument sources to be processed. This may be
   --  different from Last_Source if '--ignore=...' option specifies the list
   --  of files to be ignored.

   function Exempted_Sources return Natural;
   --  Returns the number of (existing) sources marked as ignored/exempted as
   --  the result of '--ignore=...' option.

   function Last_Argument_Source return SF_Id;
   --  Returns the Id of the last argument source stored in the source table.
   --  An argument source is the source set as the argument of the tool call.

   function Is_Argument_Source (SF : SF_Id) return Boolean;
   --  Checks if SF is from tool argument sources

   function Create_Ada_Context return Analysis_Context;
   --  Create the ``Analysis_Context`` that is going to be used to extract
   --  required information from the analyzed Ada sources.

   procedure Process_Sources (Collector : in out Diagnostic_Collector);
   --  Process Ada sources to extract exemption information from them.

   ----------------------------------------
   -- Source file access/update routines --
   ----------------------------------------

   function Source_Name (SF : SF_Id) return String;
   --  Returns the full source file name in absolute normalized form.

   function Short_Source_Name (SF : SF_Id) return String;
   --  Short file name with no directory information

   function File_Name (SF : SF_Id) return String
   is (if Tool_Args.Full_Source_Locations.Get
       then Source_Name (SF)
       else Short_Source_Name (SF));
   --  Return a string corresponding to the file name of SF, taking
   --  Full_Source_Locations into account.

   function Source_Status (SF : SF_Id) return SF_Status;
   procedure Set_Source_Status (SF : SF_Id; S : SF_Status);
   --  Queries and updates the source status.

   function Source_Info (SF : SF_Id) return SF_Info;
   procedure Set_Source_Info (SF : SF_Id; Info : SF_Info);
   --  Queries and updates the source Info value. The use of this value is up
   --  to the client of the source file table. You can store some integer-coded
   --  information or you can use this value as an index value in some other
   --  structure.

   Ignore_Unit : constant SF_Info := 1;
   --  Used to mark units to be ignored in the source table.

   procedure Set_Exemption (Fname : String);
   --  Marks the argument file in the source table as exempted (depending on
   --  the tool, either the file is not processed or no result is generated
   --  for the tool). Generates a warning if Fname does not point to argument
   --  file).

   procedure Process_Exemptions (File_List_Name : String);
   --  Reads the content of the text file that contains a list of the units to
   --  be exempts/ignored and marks the corresponding units in the source
   --  table.

   ----------------------------
   -- Temporary file storage --
   ----------------------------

   --  We use an ordered set for temporary file storage to ensure as much
   --  determinism in the tool output as possible (in case if a tool prints out
   --  the results and/or diagnostics on per-file basis).

   function File_Name_Is_Less_Than (L, R : String) return Boolean;
   --  Assuming that L and R are file names compares them as follows:
   --
   --  * first, we compare lengths of L and R Base_Names. The reason is to
   --    have in source processing bodies being processed before their subunits
   --    (if any). This is important for analysis, because if we have a
   --    generic instantiation in a separate body, the tree created for this
   --    separate body does not contains the structures for expanded body,
   --    but the tree for enclosing body does. So we have to process a subunit
   --    from the tree created for expanded body
   --
   --  then:
   --
   --  * if L and/or R contains a directory separator, compares
   --    lexicographicaly parts that follow the rightmost directory separator.
   --    If these parts are equal, compares L and R lexicographicaly
   --
   --  * otherwise compares L and R lexicographicaly
   --
   --  Comparisons are case-sensitive.

   package Temporary_File_Storages is new
     Ada.Containers.Indefinite_Ordered_Sets
       (Element_Type => String,
        "<"          => File_Name_Is_Less_Than);

   ----------------------
   -- Problem counters --
   ----------------------

   Tool_Failures : Natural := 0;
   --  Counter for tool failures a tool has recovered from

end Lkql_Checker.Source_Table;
