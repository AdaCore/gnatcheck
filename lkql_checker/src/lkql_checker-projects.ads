--
--  Copyright (C) 2005-2026, AdaCore
--  SPDX-License-Identifier: GPL-3.0-or-later
--

--  This package contains high-level interfaces to project files, based on
--  GPR2. It assumes that the tool stores its argument sources in the Source
--  Table defined in ``Lkql_Checker.Source_Table``.
--
--  *** Processing tool parameters ***
--
--  Tool options may be specified both on the command line and in the
--  tool-specific package of the project file (see
--  ``Register_Tool_Attributes``). The resulting set of options to be
--  applied is the superposition of the options from the project file and
--  from the command line in the following order:
--
--   <options from project file> <options from command line>
--
--  Precedence then depends on the kind of option: for scalar options the
--  command-line value overrides the project one, list options (``--rule``,
--  ``--lkql-path``, ...) accumulate values from both origins, and the LKQL
--  rule file is exclusive (specifying both the ``Rule_File`` attribute and
--  ``--rule-file`` is an error). To get this superposition, the tool driver
--  processes its parameters in the following order:
--
--  1. Scan the command-line parameters that must be processed before
--     loading the project file: first the early options (``--help``,
--     ``--version``, ...) which lead to an immediate exit, then the
--     project-specific options (``-P``, ``-U``, ``-X``, ``--target``,
--     ``--RTS``, ...).
--
--  2. If a project file has been specified, load it with ``Load_Project``
--     (taking into account all the other project-specific options), then
--     extract the tool options it defines with ``Extract_Tool_Options``.
--     The extraction is skipped when ``--ignore-project-switches`` is set,
--     when the tool runs in KP mode (which implies that switch), or when
--     the argument project is an aggregate project (see below).
--
--  3. Scan the tool-specific options, first the ones extracted from the
--     project file, then the ones from the command line. The same scanner
--     is used for both, which gives the required superposition.
--
--  *** Computing the argument sources ***
--
--  Once the parameters are processed, the argument sources are stored in a
--  temporary storage (see ``Lkql_Checker.Source_Table``), either from the
--  sources listed in the loaded project (see ``Get_Sources_From_Project``)
--  or from the sources given on the command line. Then,
--  ``Check_Parameters`` checks that the whole set of tool options is
--  consistent and moves the argument sources from the temporary storage
--  into the source table, checking on the way that each source exists and
--  removing duplicates.
--
--  *** Aggregate projects ***
--
--  If the argument project is an aggregate project which aggregates more
--  than one non-aggregate project, no information is extracted from the
--  aggregate project itself. Instead, the tool is spawned separately for
--  each project being aggregated (see ``Lkql_Checker.Projects.Aggregate``).

with Ada.Directories; use Ada.Directories;

with GNAT.OS_Lib; use GNAT.OS_Lib;

with GPR2.Containers;
with GPR2.Options;
with GPR2.Project.Tree;
with GPR2.Project.View;

with Lkql_Checker.String_Utilities; use Lkql_Checker.String_Utilities;

package Lkql_Checker.Projects is

   ------------------------------
   -- Project-specific options --
   ------------------------------

   --------------------------------------------------------------------------
   -- -U [main_unit]  : get the source or main_unit closure of the project --
   --------------------------------------------------------------------------

   Main_Unit : GPR2.Containers.Filename_Set;
   --  If the tool is called with "... -Pproj -U main_unit1 main_unit2 ...",
   --  main units are stored here.

   procedure Store_Main_Unit (Unit_Name : String);
   --  Processes the provided name as the main unit name for the ``-U``
   --  project file option.

   ---------------------------------------------------------
   -- Type to represent a project passed as a tool option --
   ---------------------------------------------------------

   type Arg_Project_Type is tagged private;
   --  This type represents the project file passed as a tool argument (if
   --  any), together with its loaded GPR2 project tree.

   function Tree
     (My_Project : Arg_Project_Type) return GPR2.Project.Tree.Object;
   --  Returns the GPR2 project tree of ``My_Project``

   function View
     (My_Project : Arg_Project_Type) return GPR2.Project.View.Object;
   --  Returns the GPR2 project view of ``My_Project``

   procedure Error (My_Project : Arg_Project_Type; Message : String);
   --  Emit an error message about this ``My_Project`` project

   function Is_Specified (My_Project : Arg_Project_Type) return Boolean;
   --  Checks if the argument represents a project that corresponds to some
   --  project file specified as a tool parameter.

   function Get_Project_Dir (My_Project : Arg_Project_Type) return String
   is ((if My_Project.Is_Specified and then My_Project.Tree.Is_Defined
        then
          Normalize_Pathname
            (Containing_Directory
               (My_Project.Tree.Root_Project.Path_Name.String_Value))
        else Normalize_Pathname ("./"))
       & GNAT.OS_Lib.Directory_Separator);
   --  Get the directory containing the loaded project file of ``My_Project``
   --  if there is one, otherwise, this function returns the current working
   --  directory.
   --  The string returned by this function is an absolute normalized path.

   function Get_Project_Relative_File
     (My_Project : Arg_Project_Type; Filename : String) return String
   is (My_Project.Get_Project_Dir & Filename);
   --  From the given ``Filename``, get the absolute path leading to it
   --  relatively to the current project file. If there is no specified
   --  project file, then get the file from the current directory.

   procedure Clean_Up (My_Project : Arg_Project_Type);
   --  Removes the temporary files created when processing the project. Does
   --  nothing in debug mode.

   procedure Get_Cli_Options
     (My_Project : Arg_Project_Type; Buffer : in out String_Vector);
   --  Fill the provided buffer with all GPR CLI options corresponding to the
   --  configuration of ``My_Project``.

   function Source_Prj (My_Project : Arg_Project_Type) return String;
   --  If ``My_Project.Is_Specified`` then returns the full normalized name
   --  of the project file, otherwise returns an empty string.

   function Target (My_Project : Arg_Project_Type) return String;
   --  Target name as it is specified by the command-line ``--target=...``
   --  option, or by the ``'Target`` attribute in the argument project file.

   function Ada_Runtime (My_Project : Arg_Project_Type) return String;
   --  Ada runtime as specified via ``--RTS=...`` in the command-line, or by
   --  the ``Runtime`` attribute. If no Ada runtime has been selected, this
   --  function returns an empty string.

   procedure Set_External_Values (My_Project : in out Arg_Project_Type);
   --  For each value of an external variable that has been stored as a result
   --  of the initial parameter processing, changes environment accordingly.
   --  Any inconsistencies coming from improper values of scenario variables
   --  etc. will be reported during project loading.

   procedure Set_Global_Result_Dirs (My_Project : in out Arg_Project_Type);
   --  Sets the directory to place the global tool results into.

   procedure Register_Tool_Attributes;
   --  Register tool specific attributes. In particular, the checker needs
   --  to recognize ``Codepeer.File_Patterns``.

   procedure Print_GPR_Registry (My_Project : Arg_Project_Type);
   --  If it has been required in the provided project option, print the GPR
   --  registry (formatted in JSON) and exit the program.

   function Extract_Tool_Options
     (My_Project : Arg_Project_Type) return String_Vector;
   --  Process all tool specific attributes in the provided project and return
   --  a vector containing all CLI switches for the tool extracted from the
   --  project file.

   procedure Aggregate_Project_Report_Header (My_Project : Arg_Project_Type);
   --  Prints header in the summary report file created if the argument project
   --  is an aggregate project. In this case a tool is spawned to run
   --  separately for each project being aggregated, and each such run creates
   --  its own report separate file.

   procedure Close_Aggregate_Project_Report (My_Project : Arg_Project_Type);
   --  Finalizes in the summary report file created if the argument project
   --  is an aggregate project. In this case a tool is spawned to run
   --  separately for each project being aggregated, and each such run creates
   --  its own report separate file.
   --
   --  The default version of this procedure does nothing except closing the
   --  aggregated-project-reports tag in summary XML report file (if XML report
   --  mode is ON).

   procedure Report_Aggregated_Project
     (Aggregate_Prj          : Arg_Project_Type;
      Aggregated_Prj_Name    : String;
      Expected_Text_Out_File : String;
      Expected_XML_Out_File  : String);
   --  Starts a record about processing of an aggregated project in a summary
   --  report file if the tool argument project is an aggregate project. By
   --  default, prints out the name of the aggregated project to process and
   --  the name(s) of the report file(s) that is (are) expected to be created.

   procedure Report_Aggregated_Project_Exit_Code
     (Aggregate_Prj : Arg_Project_Type; Exit_Code : Integer);
   --  Starts a record about processing of an aggregated project in a summary
   --  report file if the tool argument project is an aggregate project. By
   --  default prints out the (text image of the) exit code.

   -------------------------------------
   -- General project file processing --
   -------------------------------------

   procedure Load_Project
     (My_Project : in out Arg_Project_Type; Options : GPR2.Options.Object);
   --  From the provided GPR options, load a project file and fill the provided
   --  project object with loaded information. This function also checks that
   --  the project loading succeeded and raises error if not.

   procedure Get_Sources_From_Project (My_Project : in out Arg_Project_Type);
   --  Load sources to analyze with the tool from information stored in the
   --  provided project and store them in the dedicated internal data
   --  structure.
   --  This function assumes that the provided project has been loaded and that
   --  all command-line arguments have been processed.

   -------------------------------------
   -- General command line processing --
   -------------------------------------

   procedure Check_Parameters;
   --  Checks that the tool parameters are consistent with each other, then
   --  moves the argument sources from the temporary storage into the source
   --  table (see the package documentation above).

private

   type Arg_Project_Type is tagged record
      Tree    : aliased GPR2.Project.Tree.Object;
      View    : aliased GPR2.Project.View.Object;
      Options : GPR2.Options.Object;
   end record;

   function Tree
     (My_Project : Arg_Project_Type) return GPR2.Project.Tree.Object
   is (My_Project.Tree);

   function View
     (My_Project : Arg_Project_Type) return GPR2.Project.View.Object
   is (My_Project.View);

end Lkql_Checker.Projects;
