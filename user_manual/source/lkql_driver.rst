LKQL Driver
===========

Additionally to the ``gnatcheck`` executable, you can access the LKQL language
through the LKQL driver. This is an executable file named ``lkql`` which
defines several sub-commands, each being an entry point to the LKQL engine.

.. attention::

  While being shipped alongside GNATcheck, not all sub-commands are considered
  as stable, some are even experimental or internal and should be used with
  extreme caution.

.. _Sub_commands_List:



Sub-commands List
-----------------

Additionally to their specific switches, each sub-command accepts the
``--help`` flag which triggers the display of its specific help message and
exit.


``lkql refactor``
^^^^^^^^^^^^^^^^^

.. hint::

  This sub-command is considered as stable and is officially supported.

This sub-command is used to perform automatic refactoring operations. It is
mainly used to automatically migrate existing LKQL code-bases when a change is
made in the language syntax or sematic.

``refactor`` defines the following CLI switches:

``-i, --in-place``
  Apply refactoring directly into LKQL source files, modifying them.

``-r, --refactoring=<refactoring>``
  Name of the refactoring to apply to your LKQL files. You can view a list of
  available refactorings in the sub-command help message.

Additionally to those switches, the ``refactor`` sub-command expect a list of
LKQL files to apply the specified refactoring on. Here is an example usage:

.. code-block::

  lkql refactor -i -r=IS_TO_COLON file_1.lkql file_2.lkql


``lkql run``
^^^^^^^^^^^^

.. caution::

  This sub-command is considered as a beta feature: while being pretty stable,
  its interface may change in the future, and relying on it should be
  considered as unsafe.

This is the LKQL interpreter entry point, through it you can access the current
LKQL implementation to run any LKQL script or start a REPL. This is a good
entry point to test the LKQL language and write custom GNATcheck rules in an
iterative way.

``run`` defines the following CLI switches:

``-C, --charset=<charset>``
  Defines the charset to use for source decoding. The default is "utf-8".

``-i, --interactive``
  Start an LKQL REPL (read-eval-print loop). This switch is incompatible with
  the ``-S, --script-path`` one.

``--missing-file-is-error``
  If an Ada source file is missing, emit an error message instead of a warning
  one.

``-P, --project=<project>``
  GPR file to fetch Ada sources from for the interpreter.

``--RTS=<runtime>``
  Ada runtime to use when resolving sources.

``-S, --script-path=<script>``
  Name of the LKQL script to run. This switch is incompatible with the
  ``-i, --interactive`` one.

``--target=<target>``
  Hardware target used to resolved Ada runtime sources.

``-U, --recursive``
  Process all units in the project tree, excluding externally built project.


``-aP=<directory>``
  Add the provided directory to the project search path

``--config=<file>``
  Specify the configuration project file name

``--db=<directory>``
  Parse the provided directory as an additional knowledge base

``--db-``
  Do not load the standard knowledge base

``-eL``
  Follows symlinks for project files

``--implicit-with=<project>``
  Add the given projects as a dependency on all loaded projects

``--no-project``
  Do not use a project file

``--relocate-build-tree=<directory>``
  Relocate the build tree (object, library and executable directories) to the
  given directory. The default is the current directory.

``--root-dir=<directory>``
  Root directory of the build tree to relocate. Use this with the
  ``--relocate-build-tree`` switch.

``--src-subdirs=<directory>``
  Prepend <obj>/directory to the list of source dirs for each project

``--subdirs=<directory>``
  Use directory as suffix to obj/lib/exec directories

``-X=<name=value>``
  Specify an external reference for Project Files

``-v, --verbose``
  Enable the verbose mode.

Additionally to those switches, you can provide to the ``run`` sub-command a
list of Ada sources to use. Here is an example usage:

.. code-block::

  lkql run -S script.lkql main.adb


``lkql check``
^^^^^^^^^^^^^^

.. danger::

  This sub-command is considered as unstable and is not supported. Use it at
  your own risks.

This sub-command is used to run a set of LKQL rules on provided Ada sources.
This is an internal entry point mainly used to test GNATcheck rules.

``check`` defines the following CLI switches:

``-C, --charset=<charset>``
  Defines the charset to use for source decoding. The default is "utf-8".

``-j, --jobs=<n>``
  Number of jobs to use during analysis. If n is 0, spawn 1 job per CPU.

``-P, --project=<project>``
  GPR file to fetch Ada sources from for the interpreter.

``--RTS=<runtime>``
  Ada runtime to use when resolving sources.

``--target=<target>``
  Hardware target used to resolved Ada runtime sources.

``-U, --recursive``
  Process all units in the project tree, excluding externally built project.

``-aP=<directory>``
  Add the provided directory to the project search path

``--config=<file>``
  Specify the configuration project file name

``--db=<directory>``
  Parse the provided directory as an additional knowledge base

``--db-``
  Do not load the standard knowledge base

``-eL``
  Follows symlinks for project files

``--implicit-with=<project>``
  Add the given projects as a dependency on all loaded projects

``--no-project``
  Do not use a project file

``--relocate-build-tree=<directory>``
  Relocate the build tree (object, library and executable directories) to the
  given directory. The default is the current directory.

``--root-dir=<directory>``
  Root directory of the build tree to relocate. Use this with the
  ``--relocate-build-tree`` switch.

``--src-subdirs=<directory>``
  Prepend <obj>/directory to the list of source dirs for each project

``--subdirs=<directory>``
  Use directory as suffix to obj/lib/exec directories

``-X=<name=value>``
  Specify an external reference for Project Files

``-v, --verbose``
  Enable the verbose mode.

``--missing-file-is-error``
  If an Ada source file is missing, emit an error message instead of a warning
  one.

``--format=<format>``
  Select the final report format. Available formats are:

  * ``TEXT``: Human readable textual format, with colors when the output is
    compatible
  * ``SARIF``: A JSON output following the SARIF 2.1.0 scheme

``-I, --ignores=<ignores>``
  Files to ignore during analysis

``--rule-file=<ruleFile>``
  Provide an LKQL rule file to configure rule instances

``-r, --rule=<rule>``
  Enable the given rule for the current run. This option is cumulative.

``--rules-dir=<directory>``
  Additional directory to fetch LKQL rules from. This options is cumulative.

``-a, --rule-arg=<rule>.<arg>=<value>``
  Provide a value for a specific argument of a rule. This option is cumulative.

``--auto-fix-mode=<mode>``
  The mode to use when applying auto-fixes. Available modes are:

  * ``DISABLED``: Do not run auto-fixing functions at all
  * ``IN_REPORT``: Display fix suggestion in the report generated by the tool

Additionally to those switches, you can provide to the ``check`` sub-command a
list of Ada sources to use during analysis. Here is an example usage:

.. code-block::

  lkql check main.adb main.ads -r my_rule -a "my_rule.arg=42"

A report produced with ``--format=SARIF --auto-fix-mode=IN_REPORT`` holds the
fixes the rules suggest, which the :ref:`patch<LKQL_Patch>` sub-command applies
to the sources. Both switches are needed: only the SARIF format carries the
fixes, the ``TEXT`` one only displays them.

.. _LKQL_Patch:

``lkql patch``
^^^^^^^^^^^^^^

.. danger::

  This sub-command is considered as a prototype. Use it at your own risks, and
  mind the warning below: it modifies your sources.

This sub-command applies to Ada sources the quick fixes contained in a SARIF
report. It is the counterpart of ``check``: the checker finds violations and
computes fixes, ``patch`` puts them in the sources. Each fix is displayed with a
unified diff of what it changes and applied only if you accept it, unless
``--auto`` is given.

.. warning::

  Unless ``--dry-run`` is given, ``patch`` modifies the sources in place and
  keeps no backup of them, so applying fixes is destructive. Only run it on
  sources you can restore, that is on a project under version control.

.. hint::

  ``patch`` is best used on a code base which has already been widely analyzed
  with GNATcheck, so that the false positives have been caught and exempted
  before their fixes are applied to the sources, or on a new code base. On an
  existing one which has never been analyzed, the number of reported fixes can
  be overwhelming. This is only a recommendation though: the review can be
  interrupted at any time, and resumed later, as
  :ref:`described below<LKQL_Patch_Resuming>`.

``patch`` defines the following CLI switches:

``-a, --auto``
  Apply all the fixes without prompting.

``--dry-run``
  Go through the fixes but do not modify any file, only displaying the changes
  they would make.

``--exclude-rule=<rule>``
  Do not apply the fixes coming from the given rules. This option is
  cumulative, and accepts a comma separated list.

``--list-rules``
  Display the rules the report holds, with the number of fixes each of them
  provides, then exit without modifying anything.

``-C, --charset=<charset>``
  Defines the charset to use for source decoding. The default is "utf-8", with
  a fallback on "iso-8859-1". Sources are written back with the charset used to
  read them, and their line separators are left as they are.

Additionally to those switches, ``patch`` expects the SARIF report to apply, and
accepts a list of sources to restrict the fixes to, as described below:

.. code-block::

  lkql patch report.sarif          # review each fix before deciding
  lkql patch --auto report.sarif   # apply them all

When a fix is displayed, the following answers are accepted, each of them also
by its full name, and ``a`` and ``A`` differing only by their case:

* ``y``, ``yes``: apply this fix
* ``n``, ``no``: skip this fix
* ``a``, ``auto``: apply this fix and all the remaining ones of the same rule
* ``A``, ``all``: apply this fix and all the remaining ones, whatever their
  rule
* ``q``, ``quit``: skip this fix and all the remaining ones
* ``h``, ``help``: display what the answers mean

Sources are written only once, when all the fixes have been reviewed, so that a
run which cannot write one of its files leaves the others as they were instead
of applying a part of the fixes.

Restricting the fixes to apply
""""""""""""""""""""""""""""""

A report usually covers a whole project, while you may want to deal with one
part of it at a time. The sources given after the report restrict the fixes to
those targeting them, the others being left for a later run. Each of them may
be:

* a directory, which selects every source under it, at any depth,
* a path, which selects the source it designates,
* a bare file name, which selects the sources bearing that name, wherever they
  are in the project.

.. code-block::

  lkql patch report.sarif src/           # every source under "src"
  lkql patch report.sarif src/main.adb   # that source only
  lkql patch report.sarif main.adb       # every source named "main.adb"

Fixes can also be restricted per rule, which is useful to deal with a rule you
trust before reviewing the others, or to leave out one whose fixes you do not
want:

.. code-block::

  lkql patch --list-rules report.sarif
  lkql patch --auto --exclude-rule goto_statements report.sarif

The two restrictions combine, and what they leave out is reported at the end of
the run, so that no fix is silently dropped.

.. _LKQL_Patch_Resuming:

Stopping and resuming
"""""""""""""""""""""

The fixes applied from a report are recorded next to it, in a
``<report>.applied`` file, so rerunning the same report is harmless: the fixes
already applied are reported as such rather than applied a second time, and a
run stopped with ``q`` continues where it was left. When quitting, you are asked
whether to keep that record.

.. warning::

  That record holds the text each fix removed and inserted, so it contains
  fragments of the patched sources in clear. Protecting it, and keeping it out
  of commits and build artifacts, is left to the user. Removing it is always
  safe, the next run then considering that no fix has been applied yet, at the
  risk of applying some of them twice.

When the sources have changed
"""""""""""""""""""""""""""""

A fix designates the text to change by its position in the source the checker
analyzed. That position means nothing anymore in a source which has changed
since, where it designates something else, so ``patch`` refuses the fixes of a
file it finds modified rather than applying them blindly. The report carries the
means to detect it, so this is not something to work around: once a source has
been modified, the only way to fix it is to run the checker again and to apply
the new report.

.. note::

  A file patched by ``patch`` itself does not count as modified: as long as the
  record of what has been applied is kept, the tool knows which state the file
  is in and keeps applying the fixes which are left. Interrupting a review in
  the middle of a file is therefore safe, and resuming it later goes on with
  that same file. Only a change ``patch`` knows nothing about, made from an
  editor, or its record being discarded, makes the fixes of a file unapplicable.


``lkql doc-api``
^^^^^^^^^^^^^^^^

.. danger::

  This sub-command is considered as unstable and is not supported. Use it at
  your own risks.

Entry point used to generate API documentation for LKQL modules in the RST
format. Each LKQL file defines a module and all top level symbols are
documented.

``doc-api`` defines the following CLI switches:

``-O, --output-dir=<directory>``
  Directory path to place generated RST files in.

``--std``
  Additionally to other generated files, generate the documentation of the LKQL
  prelude and built-in functions.

Additionally to those switches, the ``doc-api`` sub-command expect a list of
LKQL files to generate documentation for. Here is an example usage:

.. code-block::

  lkql doc-api -O=doc/ --std file_1.lkql file_2.lkql


``lkql doc-rules``
^^^^^^^^^^^^^^^^^^

.. danger::

  This sub-command is considered as unstable and is not supported. Moreover,
  some information are hard-coded in it, so it should be considered as an
  internal. Use it at your own risks.

Entry point used to generate documentation for a set of LKQL rules in the RST
format.

``doc-rules`` defines the following CLI switches:

``-O, --output-dir=<directory>``
  Directory path to place generated RST files in.

``-v, --verbose``
  Enable the verbose mode.

This sub-command also expect a list of directories containing LKQL rules to
generate the documentation for. Here is an example usage:

.. code-block::

  lkql doc-rules -O=rules_doc/ rules/ other_rules/


``lkql gnatcheck_worker``
^^^^^^^^^^^^^^^^^^^^^^^^^

.. danger::

  This sub-command is considered as internal and is not meant to be used from
  the command-line.

This is the entry point of the GNATcheck driver, and it is not meant to be used
outside this context. That's why this entry point won't be documented any
further.
