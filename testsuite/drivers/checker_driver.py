import re
import os

from base_driver import BaseDriver, TaggedLines

from e3.testsuite.driver.diff import OutputRefiner, Substitute


class CheckerDriver(BaseDriver):
    """
    This driver runs the checker with the given arguments and compares the
    checkers's output to the provided output file.

    This driver supports the flag checking procedure.
    Ada lines flagged by the checker must be annotated with `-- FLAG`. The
    number of `FLAG` on the line must be equals to the number of times
    the line is flagged by the driver.

    Test arguments:
        - project: GPR build file to use (if any)
        - input_sources: Ada files to analyze (if explicit, optional if project
          is passed)
        - rule_name: The name of the rule to check
        - rule_arguments: A dict mapping rule argument names to their values
        - auto_fix: If 'True', enable auto-fix for enabled rules
    """

    perf_supported = True
    flag_checking_supported = True

    _flag_line_pattern = re.compile(
        rf"^({BaseDriver.ada_file_pattern}):(\d+):\d+: rule violation: .*$"
    )

    def run(self) -> None:
        args = []

        # Use the test's project, if any
        if self.test_env.get("project", None):
            args += ["-P", self.test_env["project"]]
        else:
            args += self.test_env["input_sources"]

        # Use the wanted charset, if any
        if self.test_env.get("source_charset"):
            args += ["--charset", self.test_env["source_charset"]]

        for k, v in self.test_env.get("rule_arguments", {}).items():
            args += ["--rule-arg", "{}={}".format(k, v)]

        args += ["-r", self.test_env["rule_name"]]
        args += ["--rules-dir", self.test_env["test_dir"]]

        if self.test_env.get("missing_file_is_error", True):
            args += ["--missing-file-is-error"]

        # Enable auto-fixes in the LKQL output if required
        if self.test_env.get("auto_fix"):
            args += ["--auto-fix-mode", "IN_REPORT"]

        # Run the checker
        if self.perf_mode:
            self.perf_run(args)
        else:
            # Use `catch_error=False` to avoid failing on non-zero status code,
            # as some tests actually exert erroneous behaviors.
            self.check_run(
                self.lkql_checker_exe + args,
                catch_error=False,
                lkql_path=os.environ["LKQL_PATH"],
            )

    def parse_flagged_lines(self, output: str) -> dict[str, TaggedLines]:
        # Prepare the result
        res: dict[str, TaggedLines] = {}

        # For each line of the output search the groups in the line
        for line in output.splitlines():
            search_result = self._flag_line_pattern.search(line)
            if search_result is not None:
                (file, _, line_num) = search_result.groups()
                if not res.get(file):
                    res[file] = TaggedLines()
                res[file].tag_line(int(line_num))

        # Return the result
        return res

    @property
    def output_refiners(self) -> list[OutputRefiner]:
        result = super().output_refiners
        # Insert this refiner first in the list so that canonicalize_backslashes
        # is run after the following substitution.
        result.insert(0, Substitute(self.test_env["test_dir"], "<test-dir>"))
        return result
