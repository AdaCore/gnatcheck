# GNATcheck and GNATkp

This is the official repository for GNATcheck and GNATkp. Their source code was
previously hosted in the [LKQL
repository](https://gitlab.adacore-it.com/eng/libadalang/langkit-query-language)
and has since been moved here.

## Overview

**GNATcheck** is a utility that checks Ada source files against a set of
syntactic and semantic rules, which can be used to enforce coding standards or
detect potential errors and problematic code patterns. Rules are written in
[LKQL](https://gitlab.adacore-it.com/eng/libadalang/langkit-query-language);
GNATcheck ships with a set of predefined rules, and users may write their own.

**GNATkp** (GNAT Known Problem detector) is a special packaging of GNATcheck
available to GNAT Pro Assurance customers. It replaces the coding standard rules
with rules designed to detect constructs affected by known problems in official
compiler releases. GNATkp comes in addition to, not as a replacement of,
GNATcheck.

