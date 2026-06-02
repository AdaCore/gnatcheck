#!/usr/bin/env python3

import argparse
import glob
import inspect
import os
import shutil
import sys
from impactdb import db
from pathlib import Path


UTILS_DIR = os.path.dirname(os.path.abspath(__file__))
KP_DIR = os.path.join(UTILS_DIR, "..", "lkql_checker", "share", "lkql", "kp")
TESTS_DIR = os.path.join(UTILS_DIR, "..", "testsuite", "tests", "checks")


def format_id(name: str) -> str:
    """Convert a KP name (e.g. kp_u928_018) to an impact-db issue
    id (e.g. U928-018)."""
    return name[3:].upper().replace("_", "-")


def list_kps(kp_dir: str) -> list[str]:
    """Return the sorted list of KP names (e.g. kp_18614) found by
    recursively looking for .lkql files in ``kp_dir``."""
    names = {
        Path(f).stem
        for f in glob.glob(os.path.join(kp_dir, "**", "*.lkql"), recursive=True)
    }
    return sorted(names)


def load_entries() -> dict:
    """Map impact-db issue ids (names and origins) to their entry file."""
    entries_dir = os.path.join(os.path.dirname(inspect.getfile(db)), "..", "entries")
    entries = {}
    for e in db.load(entries_dir):
        if e.type != "kp":
            continue
        path = os.path.join(
            entries_dir, db.name_to_entries_dir(e.name), e.name + ".yaml"
        )
        entries[e.name] = path
        origin = e.get("origin", "")
        if origin:
            entries[origin] = path
    return entries


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Package each KP whose .lkql detector is found in the KP"
        " directory with its impact-db entry and its tests. Exit with a"
        " non-zero status if a KP has no test."
    )
    parser.add_argument(
        "location", help="directory in which to create the kps directory"
    )
    parser.add_argument(
        "--kp-dir",
        default=KP_DIR,
        help="directory searched recursively for the KP .lkql detectors"
        " (default: the kp directory in lkql_checker)",
    )
    parser.add_argument(
        "--tests-dir",
        default=TESTS_DIR,
        help="directory containing the KP tests (default: the checks"
        " directory of the testsuite)",
    )
    args = parser.parse_args()

    kps_dir = os.path.join(args.location, "kps")
    os.makedirs(kps_dir, exist_ok=True)

    names = list_kps(args.kp_dir)

    entries = load_entries()
    status = 0

    for name in names:
        id = format_id(name)
        kp_dir = os.path.join(kps_dir, name)
        os.makedirs(kp_dir, exist_ok=True)

        # Copy the impact-db entry
        entry_file = entries.get(id)
        if entry_file:
            shutil.copy(entry_file, kp_dir)
        else:
            print(f"warning: no impact-db entry found for {id}")

        # Copy the matching tests
        test_dir = os.path.join(args.tests_dir, "KP-" + id)
        if os.path.isdir(test_dir):
            shutil.copytree(
                test_dir,
                os.path.join(kp_dir, "test"),
                dirs_exist_ok=True,
            )
        else:
            print(f"error: no test found for KP-{id}", file=sys.stderr)
            status = 1

    sys.exit(status)


if __name__ == "__main__":
    main()
