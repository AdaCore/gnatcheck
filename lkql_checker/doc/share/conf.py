# -*- coding: utf-8 -*-
#
# GNATcheck/GNATkp build configuration file

# -- Project information -----------------------------------------------------

import os
from os import path as P
import sys
from sphinx.highlighting import lexers
import time

from docutils import nodes
from sphinx import addnodes

# Add own dir path
own_dir_path = P.dirname(P.realpath(__file__))
sys.path.append(own_dir_path)

# Add lkql user_manual path into the Python path, so that we have access to the
# lkql pygments lexer module.
lkql_user_manual_path = P.join(
    P.dirname(P.dirname(P.dirname(P.dirname(P.realpath(__file__))))),
    "user_manual",
    "source",
)

sys.path.append(lkql_user_manual_path)

import ada_pygments  # noqa: E402
import latex_elements  # noqa: E402
import lkql_lexer  # noqa: E402

# -- General configuration ---------------------------------------------------

lexers["lkql"] = lkql_lexer.LKQLPygmentsLexer()
lexers["ada"] = ada_pygments.AdaLexer()
lexers["gpr"] = ada_pygments.GNATProjectLexer()

# -- General configuration ---------------------------------------------------

# Add any paths that contain custom static files (such as style sheets) here,
# relative to this directory. They are copied after the builtin static files,
# so a file named "default.css" will overwrite the builtin "default.css".

# The documentation to build is selected through the DOC_NAME environment
# variable (set by the Makefile), defaulting to the GNATcheck manual.
doc_name = os.environ.get("DOC_NAME", "gnatcheck_rm")

doc_projects = {
    "gnatcheck_rm": "GNATcheck Reference Manual",
    "gnatkp_rm": "GNATkp Reference Manual",
}

# TODO: Add back the lkql syntax check, factor it from LKQL's user manual
extensions = ["sphinx.ext.viewcode", "lkql_doc_class"]
exclude_patterns = ["generated/lal_api.rst"]

# Exclude the sources of the other documentations from the build
exclude_patterns += ["%s.rst" % name for name in doc_projects if name != doc_name] + [
    "%s/*" % name for name in doc_projects if name != doc_name
]
if doc_name != "gnatcheck_rm":
    exclude_patterns.append("generated/*")

templates_path = ["_templates"]
source_suffix = ".rst"
master_doc = doc_name

# General information about the project.
project = doc_projects[doc_name]
copyright = "2008-%s, AdaCore" % time.strftime("%Y")
author = "AdaCore"


def get_version():
    for line in open("../../src/lkql_checker-options.ads").readlines():
        if line.lstrip().startswith("Lkql_Checker_Version"):
            return line[line.find('"') + 1 : line.rfind('"')]
    raise Exception("Could not find the current version of GNATcheck")


version = get_version()
release = version

pygments_style = "sphinx"

html_theme = "sphinx_rtd_theme"
if P.isfile("favicon.ico"):
    html_favicon = "favicon.ico"

html_logo = "adacore-logo-white.png"
html_theme_options = {
    "style_nav_header_background": "#12284c",
    "navigation_depth": 5,
}

latex_additional_files = ["gnat.sty"]

latex_elements = {
    "preamble": latex_elements.TOC_DEPTH
    + latex_elements.PAGE_BLANK
    + latex_elements.TOC_CMD
    + latex_elements.LATEX_HYPHEN
    + latex_elements.doc_settings(project, get_version()),
    "tableofcontents": latex_elements.TOC,
}

latex_documents = [(master_doc, "%s.tex" % doc_name, project, "AdaCore", "manual")]

texinfo_documents = [(master_doc, doc_name, project, "AdaCore", doc_name, doc_name, "")]


def _typeref_role(role, rawtext, text, lineno, inliner, options={}, content=[]):
    name = text.replace("_", "")
    if name == "Pragma":
        name = "PragmaNode"
    node = addnodes.pending_xref(
        rawtext,
        nodes.literal(name, name),
        refdomain="std",
        reftype="ref",
        reftarget="lal-" + name.lower(),
        refexplicit=True,
    )
    return [node], []


def _rmlink_role(role, rawtext, text, lineno, inliner, options={}, content=[]):
    url = (
        "http://www.ada-auth.org/standards/22rm/html/rm-"
        + text.replace(".", "-")
        + ".html"
    )
    node = nodes.reference(rawtext, "ARM " + text, refuri=url, **options)
    return [node], []


def setup(app):
    app.add_role("typeref", _typeref_role)
    app.add_role("rmlink", _rmlink_role)
