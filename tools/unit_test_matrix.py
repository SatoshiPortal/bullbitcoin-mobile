#!/usr/bin/env python3
"""Build the GitHub Actions matrix for impacted workspace unit tests.

Every selected member with a test/ directory gets an independently rerunnable
job. Only the root application is split into three file-based sub-shards. An
explicit no-op entry keeps the matrix valid when the selected members have no
test directories.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Mapping, Optional, Sequence, Tuple

try:
    from tools.impacted_unit_tests import (
        FULL,
        IMPACTED,
        Runner,
        ToolError,
        load_members,
        run_subprocess,
    )
except ModuleNotFoundError:  # Direct execution: python3 tools/unit_test_matrix.py
    from impacted_unit_tests import (
        FULL,
        IMPACTED,
        Runner,
        ToolError,
        load_members,
        run_subprocess,
    )

ROOT_PACKAGE = "bb_mobile"
ROOT_SHARDS = 3
MULTI_VIEW_PACKAGES = frozenset({"secrets", "sync"})


def selected_packages(
    *, mode: str, packages: str, members: Mapping[str, str]
) -> Tuple[str, ...]:
    if mode == FULL:
        if packages:
            raise ToolError("full mode requires an empty package selection")
        return tuple(sorted(members))
    if mode != IMPACTED:
        raise ToolError(f"unsupported unit-test mode {mode!r}")
    selected = tuple(packages.split(",")) if packages else ()
    if any(not package for package in selected):
        raise ToolError("impacted package selection contains an empty name")
    if len(set(selected)) != len(selected):
        raise ToolError("impacted package selection contains a duplicate name")
    unknown = sorted(set(selected) - set(members))
    if unknown:
        raise ToolError(
            "impacted package selection contains unknown members: "
            + ", ".join(unknown)
        )
    return tuple(sorted(selected))


def build_jobs(
    *,
    mode: str,
    packages: str,
    members: Mapping[str, str],
    workspace: Path,
) -> Tuple[list[dict], bool]:
    """Return matrix include entries and whether multi-view tests are needed."""
    selected = selected_packages(mode=mode, packages=packages, members=members)
    jobs = []
    for package in selected:
        location = members[package]
        if not (workspace / location / "test").is_dir():
            continue
        shards = ROOT_SHARDS if package == ROOT_PACKAGE else 1
        for shard in range(shards):
            suffix = f" (shard {shard + 1} of {shards})" if shards > 1 else ""
            jobs.append(
                {
                    "name": f"Unit tests / {package}{suffix}",
                    "package": package,
                    "run": True,
                    "shard": shard,
                    "shards": shards,
                }
            )
    if not jobs:
        jobs.append(
            {
                "name": "Unit tests / no impacted test suites",
                "package": "",
                "run": False,
                "shard": 0,
                "shards": 1,
            }
        )
    multi_view = mode == FULL or bool(MULTI_VIEW_PACKAGES.intersection(selected))
    return jobs, multi_view


def github_output(jobs: list[dict], multi_view: bool) -> str:
    return (
        "jobs<<BULL_UNIT_TEST_MATRIX\n"
        + json.dumps(jobs, separators=(",", ":"))
        + "\nBULL_UNIT_TEST_MATRIX\n"
        + f"multi_view={'true' if multi_view else 'false'}\n"
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=(FULL, IMPACTED), required=True)
    parser.add_argument("--packages", default="")
    parser.add_argument("--workspace", default=os.curdir)
    parser.add_argument("--fvm", default="fvm")
    parser.add_argument("--output", help="Append the GitHub output block to this file")
    return parser


def main(
    argv: Optional[Sequence[str]] = None,
    *,
    run: Runner = run_subprocess,
    stdout=None,
) -> int:
    args = build_parser().parse_args(argv)
    out = stdout if stdout is not None else sys.stdout
    try:
        members = load_members(run, args.fvm)
        jobs, multi_view = build_jobs(
            mode=args.mode,
            packages=args.packages,
            members=members,
            workspace=Path(args.workspace),
        )
        payload = github_output(jobs, multi_view)
        if args.output:
            with open(args.output, "a", encoding="utf-8") as handle:
                handle.write(payload)
    except (ToolError, OSError) as error:
        print(f"unit_test_matrix: {error}", file=sys.stderr)
        return 1
    json.dump({"jobs": jobs, "multi_view": multi_view}, out, indent=2)
    out.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
