.. _LKQL_V2:

LKQL V2 documentation
#####################

.. warning::

  LKQL V2 is still in beta.
  It is not yet ready for production.
  Use at your own discretion.

Changes to V1
=============

Some operations (selectors and list comprehensions) have been made lazy
(or lazier). This has very few to no overhead in the most cases, and
some others can be a powerful optimization compared to before.

What’s new in V2
================

LKQL V2 will be statically typed. This will help users write better
code, and will allow us to provide a VS Code extension and a Language
Server for LKQL.

The syntax is also updated, new types were added and some concepts were
reworked to be easier to work with.

CLI
---

Refactor tool
^^^^^^^^^^^^^

In order to facilitate migrating to LKQL V2, the refactor tool has a new
refactor mode. Users can rewrite LKQL V1 code as such

.. code:: sh

   lkql refactor -r TO_LKQL_V2 script.lkql

This tool has some limitations:

1. it will not format code properly
2. it cannot refactor dynamic objects
3. it will sometimes produce invalid
   code because of the disparities between ``List`` and ``Stream``
4. it cannot infer types and will thus annotate variables with an ``Any`` type
   placeholder

A formater will be made available to solve 1. 2 and 3 will require
slight human intervention to make the refactored code behave properly.

4 does not prevent users from running LKQL V2 code, but we encourage
adding type annotations since we plan on making well-typed code a
requirement in future releases.

Typechecking flag
^^^^^^^^^^^^^^^^^

With LKQL V2 being statically typed, users can now detect type errors before running their code.

.. code:: sh

   lkql run --typecheck-mode=<WARN|DISABLE|STRICT> script.lkql

By default, type errors will only be reported as warnings.

By adding the ``--typecheck-mode=STRICT`` flag, users can make type errors stop execution.
We recommend adding this flag whenever possible since in future LKQL releases,
we plan on making typechecking a strict requirement.

Conversely, by adding ``--typecheck-mode=DISABLE``, users can silence the type errors.
This recreates the previous behavior.

Streams
-------

The refactor tool will sometimes produce code with type errors. The
mistmatch between ``Stream`` and ``List`` object is very easy to
resolve, as it is possible to convert between the two with a builtin
method.

Conversions:

* ``List.to_stream`` builtin
* ``Stream.to_list`` builtin

Stream operators:

* ``head :: tail`` for cons-ing streams
* ``start ::: end`` for concatenating streams

Stream builtins:

* ``Stream.any((T) -> Bool)``/``Stream.all((T) -> Bool)``
* users should replace usages of ``Stdlib.any(Stream[Bool])``/``Stdlib.all(Stream[Bool])`` with the new builtins
* ``Stream.map``/``Stream.flat_map``/``Stream.reduce``
* users should replace usages of ``map``/``flat_map``/``reduce`` global functions with the new builtins
* if necessary, convert lists to streams using the ``List.to_stream`` operation

Replacing selectors
~~~~~~~~~~~~~~~~~~~

Streams are a simpler and more general aproach to lazy iteration than
selectors previously were. This is why selectors have been removed.

The refactor tool will translate selectors into functions returning
streams. They are wrapped in a lot of code by the refactor tool to
produce strictly identical streams, but in general users should expect
to rewrite selectors with stream code manually. The refactored selectors
will be **significatively slower** (~4 times slower) than before, but
when rewriten by hand, the same level of performance should be
attainable.

This has already been done for the ``children`` selector which should be
replaced by the new ``subtree`` function returning a stream.

In order to be refactored correctly, the selectors need to be
well-formed and always return a ``rec`` expression. We also allow
``null`` and ``()`` as valid return options since this pattern was used
throughout our codebases.

Also, previous notions of selector ``[min/max]depth`` should now be
handled by general recursive mechanisms and are not built in anymore.

Patterns
--------

Because selectors are now nothing but simple functions, the concept of a
selector pattern is now unnecessary. Old selectors patterns can be
rewritten as patterns with a ``when`` boolean condition using the new
``Stream.all/any`` builtins. The refactor tool will handle this
automatically.

Safe access / safe calls
------------------------

Safe calls have been removed. Instead, calling a property obtained
through safe acess has the same behavior than a safe call of this
property.

Indexing
--------

Indexing changed from 1-based to 0-based to match the semantics of Lkt.
- users should replace usages of ``sublist`` with the new ``List.span``
builtin - users should replace usages of ``enumerate`` with the new
``Stream.with_index`` builtin

Moreover, in V1, all indexing operations (``list[idx]``/``list?[idx]``)
used to be null-safe, and the safe index (``list?[idx]``) was also
OOB-safe. - Now, the new behavior is to be null-**unsafe**. - Null-safe
indexing is done with the safe-index/safe-call operator (respectively
``some_null_var?[idx]``/``some_null_var.?at(idx)``) builtin. - The safe
indexing operation is now null-safe but OOB-**unsafe**. - OOB-safe
indexing is done with the ``List.at(idx)`` builtin. It will return
``null`` instead of ``Unit()`` in the case of an OOB.

The refactor will sometimes produce streams indexed with ``at``. This
will require a manual rewrite. For now, a stream indexed with
``stream[idx]`` is still working, but enventually we want to disallow
indexing into streams as a whole.

Constructors
------------

Refactored code need to import the refactoring module as such

.. code:: diff

   +import libadalang_rewriting as lal_rw

   -val mynode =        SomeConstructor(arg1=x1, arg2=x2)
   +val mynode = lal_rw.SomeConstructor(arg1=x1, arg2=x2)

Token node / List node constructors need to be updated manually. They
take a single argument (``_token``, and ``_elements`` respectively). We
eventually want to allow constructors with only one argument to be
called without explicitely naming the argument.

Because rewriting constructors expect rewriting nodes as input, users
should now use ``Node.to_rewriting`` builtin for explicit type
conversions between a regular node and a rewriting one.

