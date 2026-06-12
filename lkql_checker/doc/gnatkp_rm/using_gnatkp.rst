.. _using_gnatkp:

************
Using GNATkp
************

``gnatkp`` (GNAT Known Problem detector) is a tool that allows to detect
constructs affected by specific known problems in official GNAT Pro compiler
releases. This tool is available as part of GNAT Pro Assurance subscriptions.
Note that GNATkp is based on GNATcheck, but is not a replacement of GNATcheck,
which requires a distinct GNAT SAS subscription.

You can use the command ``gnatkp --help`` to list all the switches
relevant to GNATkp. GNATkp mostly accepts the same command arguments as
GNATcheck and behaves in a similar way, but there are some differences
that are described below.

The topics common to both tools are covered by the GNATcheck Reference
Manual and are not duplicated here. In particular, refer to the
following sections of that manual:

* "General GNATcheck Switches", for project file support and the
  general command line switches;
* "Rule Exemption", for the exemption mechanism;
* "Format of the Report File", for the format of the report file and
  the related switches;
* "GNATcheck Exit Codes", for the tool exit codes;
* "Performance and Memory Usage", for performance and memory usage
  considerations.

.. _Detecting_Known_Problems_For_a_Given_Version:

Detecting Known Problems For a Given Version
============================================

The easiest way to use GNATkp is by specifying the version of GNAT Pro that
you have and letting ``gnatkp`` run all known problem detectors
registered for this version, via the switch ``--kp-version``. For example:

.. code-block:: none

  gnatkp -Pproject --kp-version=21.2 --target=<my_target> --RTS=<my_runtime>

will run all detectors relevant to GNAT Pro 21.2 on all files in the
project. The list of detectors will be displayed as info messages, and will
also be listed in the file :file:`gnatkp-rule-list.out`. The list of detected
source locations will be generated on standard error, as well as in a file
called :file:`gnatkp.out`.

A bare major version number may also be used (e.g. ``--kp-version=21``) to
enable all detectors relevant to any minor release of that major version
(21.1, 21.2, etc.).

You can display the list of detectors without running them by specifying
additionally the ``--list-rules`` switch, e.g.:

.. code-block:: none

  gnatkp --kp-version=21.2 --list-rules --target=<my_target> --RTS=<my_runtime>

You can also combine the ``--kp-version`` switch with the ``--target`` switch
to filter out detectors not relevant for your target, e.g:

.. code-block:: none

  gnatkp -Pproject --kp-version=21.2 --target=powerpc-elf --RTS=<my_runtime>

will only enable detectors relevant to GNAT Pro 21.2 and to the ``powerpc-elf``
target.

Note that you need to have the corresponding target GNAT compiler installed
to use this option. By default, detectors for all targets are enabled.

.. _Running_Specific_Detectors:

Running Specific Detectors
==========================

It is also possible to specify the custom list of detectors for GNATkp to run
using the switch ``-r``:

.. code-block:: none

  gnatkp -Pproject --target=<my_target> --RTS=<my_runtime> -r kp_xxxx_xxx [-r kp_xxxx_xxx]

where ``kp_xxxx_xxx`` is the name of a relevant known-problem to detect. You
can get the list of available detectors via the command
``gnatkp --list-rules``. When combined with the ``--kp-version`` and possibly
``--target`` switches, ``gnatkp --list-rules`` will only list the detectors
relevant to the version (and target) specified.

.. attention::

  You must provide explicit target and runtime (either through the command-line
  or with a provided project file) when running GNATkp to ensure the result
  soundness.

.. note::

  The exemption mechanism described in the GNATcheck Reference Manual is
  available for GNATkp as well but you have to change pragmas and comments
  a bit to avoid conflict with GNATcheck exemptions. Thus, pragmas
  annotations' first argument must be ``gnatkp`` instead of ``gnatcheck``:

  .. code-block:: ada

    pragma Annotate (gnatkp, Exempt_On, "kp_19198", "Justification");

  And exemption comments' first word must be ``kp`` instead of ``rule``,
  example:

  .. code-block:: ada

    --## kp off kp_19198 ## Justification

You can check via the GNAT Tracker interface which known problems are
relevant to your version of GNAT and your target before deciding which
known problems may impact you: most known problems are only relevant to a
specific version of GNAT, a specific target, or a specific usage profile. Do
not hesitate to contact the AdaCore support if you need help identifying the
entries that may be relevant to you.
