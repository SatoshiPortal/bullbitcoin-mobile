#!/usr/bin/env python3
"""Select the workspace members whose unit tests a pull request impacts.

Runs after the Flutter/Melos setup. `melos list --json --relative` names the
workspace members and their locations, and `git diff --name-only --no-renames -z
BASE...HEAD` lists both sides of the file changes. Each file is attributed to the member
with the longest matching location, the root package never absorbs a child
member, and every directly changed member's transitive dependents are added
through `melos list --depends-on=<name> --include-dependents --json --relative`.

Melos' own `--diff` filter is deliberately not used: it attributes a change made
under a child member to the root package as well, so every pull request would
run the root app even for an unrelated member. `--graph` and `--long` are not
used either: in melos 8.10.1 they omit the root package's dependency edges.

Anything the classifier cannot attribute with confidence falls back to the full
suite. A failing git or melos call, an unusable path or an incoherent workspace
description is an error with a non-zero exit, never a silent full run: a green
run must never hide untested members.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from typing import Callable, List, Mapping, Optional, Sequence, Tuple

IMPACTED = "impacted"
FULL = "full"

PULL_REQUEST = "pull_request"
PUSH = "push"
WORKFLOW_DISPATCH = "workflow_dispatch"
EVENTS = (PULL_REQUEST, PUSH, WORKFLOW_DISPATCH)
# Events with no pull request range: the whole workspace always runs, without
# asking git or melos anything.
FULL_EVENTS = frozenset({PUSH, WORKFLOW_DISPATCH})

# Root paths that belong to the root app package. Every other root file
# (manifests, lockfiles, SDK pin, makefile, workflows, scripts, containers, docs)
# affects the whole workspace, so it forces a full run.
ROOT_ATTRIBUTABLE_PREFIXES = (
    "lib/",
    "test/",
    "integration_test/",
    "localization/",
    "assets/",
)

# Native and build-hook sources are shared by every member that compiles them.
NATIVE_SEGMENTS = frozenset(
    {"hook", "rust", "android", "ios", "linux", "macos", "windows"}
)


class ToolError(Exception):
    """A failed git or melos call, or an incoherent workspace description."""


class UsageError(ToolError):
    """An invalid invocation; reported with exit code 2."""


@dataclass(frozen=True)
class Result:
    """Outcome of one external command, kept undecoded for binary-safe paths."""

    returncode: int
    stdout: bytes
    stderr: bytes


Runner = Callable[[Sequence[str]], Result]


@dataclass(frozen=True)
class Plan:
    """What the unit test job must run.

    `full` always means every workspace member runs. For `push` and
    `workflow_dispatch` the member set is never computed, so `selected` is empty
    there too: the mode alone decides.
    """

    mode: str
    event: str
    changed: Tuple[str, ...]
    selected: Tuple[str, ...]
    excluded: Tuple[str, ...]
    reason: str
    base: Optional[str] = None
    head: Optional[str] = None

    @property
    def packages(self) -> str:
        """The Melos scope CSV. Empty means no `--scope`, so everything runs."""
        if self.mode != IMPACTED:
            return ""
        return ",".join(self.selected)

    def to_json(self) -> dict:
        payload = {"mode": self.mode, "event": self.event}
        if self.base is not None:
            payload["base"] = self.base
            payload["head"] = self.head
        payload.update(
            changed=list(self.changed),
            selected=list(self.selected),
            excluded=list(self.excluded),
            reason=self.reason,
        )
        return payload


@dataclass(frozen=True)
class Attribution:
    """The member a file belongs to, or why it forces a full run."""

    member: Optional[str]
    reason: Optional[str]


def run_subprocess(command: Sequence[str]) -> Result:
    try:
        completed = subprocess.run(command, capture_output=True, check=False)
    except OSError as error:
        # A missing or unusable executable is an error, never a silent fallback.
        raise ToolError(f"cannot run {command[0]}: {error}") from error
    return Result(completed.returncode, completed.stdout, completed.stderr)


def _decode(payload: bytes) -> str:
    return payload.decode("utf-8", errors="replace")


def _require_success(result: Result, command: Sequence[str], what: str) -> None:
    if result.returncode == 0:
        return
    detail = _decode(result.stderr).strip() or _decode(result.stdout).strip()
    if len(detail) > 2000:
        detail = detail[-2000:]
    raise ToolError(
        f"{what} failed with exit {result.returncode}: {' '.join(command)}"
        + (f"\n{detail}" if detail else "")
    )


def _normalise_location(location: str, command: Sequence[str]) -> str:
    """Turn a melos location into a workspace-relative path, "" for the root."""
    path = location.strip()
    while path.startswith("./"):
        path = path[2:]
    path = path.rstrip("/")
    if path in ("", "."):
        return ""
    if path.startswith("/") or ".." in path.split("/"):
        raise ToolError(
            f"melos list returned an unusable location {location!r} in "
            f"{' '.join(command)}"
        )
    return path


def _parse_melos_json(payload: bytes, command: Sequence[str]) -> list:
    """Parse the JSON array melos prints, tolerating a warning prefix on stdout."""
    text = _decode(payload)
    if not text.strip():
        raise ToolError(f"melos list printed nothing: {' '.join(command)}")
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    start = text.find("[")
    if start >= 0:
        try:
            value, end = json.JSONDecoder().raw_decode(text, start)
        except json.JSONDecodeError:
            value = None
        else:
            if not text[end:].strip():
                print(
                    f"impacted_unit_tests: skipped {start} byte(s) of non-JSON "
                    f"output before the melos list payload",
                    file=sys.stderr,
                )
                return value
    raise ToolError(f"melos list did not print a JSON array: {' '.join(command)}")


def _parse_melos_entry(entry: object, command: Sequence[str]) -> Tuple[str, str]:
    if not isinstance(entry, dict):
        raise ToolError(
            f"melos list returned a non-object entry in {' '.join(command)}"
        )
    name = entry.get("name")
    location = entry.get("location")
    if not isinstance(name, str) or not name:
        raise ToolError(f"melos list returned an entry without a name: {entry!r}")
    if not isinstance(location, str):
        raise ToolError(f"melos list returned no location for {name!r}")
    return name, _normalise_location(location, command)


def load_members(run: Runner, fvm: str) -> Mapping[str, str]:
    """Return the workspace members as name -> workspace-relative location."""
    command = [fvm, "dart", "run", "melos", "list", "--json", "--relative"]
    result = run(command)
    _require_success(result, command, "melos list")
    entries = _parse_melos_json(result.stdout, command)
    if not isinstance(entries, list):
        raise ToolError(f"melos list did not print a JSON array: {' '.join(command)}")
    members: dict = {}
    locations: dict = {}
    for entry in entries:
        name, location = _parse_melos_entry(entry, command)
        if name in members:
            raise ToolError(f"melos list names the member {name!r} twice")
        if location in locations:
            raise ToolError(
                f"melos list gives the same location {location!r} to "
                f"{locations[location]!r} and {name!r}"
            )
        members[name] = location
        if location:
            locations[location] = name
    roots = [name for name, location in members.items() if location == ""]
    if len(roots) != 1:
        raise ToolError(
            f"melos list must describe exactly one root package, found {len(roots)}"
        )
    return members


def root_member(members: Mapping[str, str]) -> str:
    return next(name for name, location in members.items() if location == "")


def load_dependents(run: Runner, fvm: str, name: str) -> List[str]:
    """Return the transitive dependents melos reports for a member."""
    command = [
        fvm,
        "dart",
        "run",
        "melos",
        "list",
        f"--depends-on={name}",
        "--include-dependents",
        "--json",
        "--relative",
    ]
    result = run(command)
    _require_success(result, command, f"melos list --depends-on={name}")
    entries = _parse_melos_json(result.stdout, command)
    if not isinstance(entries, list):
        raise ToolError(f"melos list did not print a JSON array: {' '.join(command)}")
    return [_parse_melos_entry(entry, command)[0] for entry in entries]


def changed_files(run: Runner, base: str, head: str) -> List[str]:
    """Return both sides of renames so old and new members remain covered."""
    command = [
        "git",
        "diff",
        "--name-only",
        "--no-renames",
        "-z",
        f"{base}...{head}",
        "--",
    ]
    result = run(command)
    _require_success(result, command, f"git diff {base}...{head}")
    return [os.fsdecode(item) for item in result.stdout.split(b"\0") if item]


def attribute(path: str, members: Mapping[str, str], root: str) -> Attribution:
    """Attribute one changed path to a member, or explain why it forces full."""
    segments = path.split("/")
    if not path or path.startswith("/") or ".." in segments:
        return Attribution(None, f"{path!r} is not a workspace-relative path")
    if segments[-1] == "pubspec.lock":
        return Attribution(
            None, f"{path} changes dependency resolution for the workspace"
        )
    native = next(
        (segment for segment in segments if segment.lower() in NATIVE_SEGMENTS), None
    )
    if native is not None:
        return Attribution(
            None, f"{path} touches {native} sources, which every member builds"
        )
    owner = None
    for name, location in members.items():
        if not location:
            continue
        if path == location or path.startswith(location + "/"):
            if owner is None or len(location) > len(members[owner]):
                owner = name
    if owner is not None:
        return Attribution(owner, None)
    if any(path.startswith(prefix) for prefix in ROOT_ATTRIBUTABLE_PREFIXES):
        return Attribution(root, None)
    prefixes = ", ".join(prefix.rstrip("/") for prefix in ROOT_ATTRIBUTABLE_PREFIXES)
    return Attribution(
        None,
        f"{path} is a root file outside {prefixes}, so it affects the whole workspace",
    )


def _full_plan(
    *,
    event: str,
    reason: str,
    members: Optional[Mapping[str, str]] = None,
    base: Optional[str] = None,
    head: Optional[str] = None,
) -> Plan:
    selected = tuple(sorted(members)) if members is not None else ()
    return Plan(
        mode=FULL,
        event=event,
        changed=(),
        selected=selected,
        excluded=(),
        reason=reason,
        base=base,
        head=head,
    )


def plan(
    *,
    event: str,
    base: Optional[str],
    head: Optional[str],
    run: Runner,
    fvm: str = "fvm",
) -> Plan:
    """Decide the mode and the selected members for one workflow run."""
    if event in FULL_EVENTS:
        return _full_plan(
            event=event,
            reason=f"{event} carries no pull request range; every member runs",
        )
    if event != PULL_REQUEST:
        raise UsageError(f"unsupported event {event!r}")
    if not base or not head:
        raise UsageError("--base and --head are required for pull_request")

    members = load_members(run, fvm)
    root = root_member(members)
    paths = changed_files(run, base, head)
    if not paths:
        return _full_plan(
            event=event,
            reason=f"no file differs between {base} and {head}",
            members=members,
            base=base,
            head=head,
        )

    changed = set()
    for path in paths:
        attribution = attribute(path, members, root)
        if attribution.member is None:
            return _full_plan(
                event=event,
                reason=attribution.reason or f"{path} cannot be attributed",
                members=members,
                base=base,
                head=head,
            )
        changed.add(attribution.member)

    selected = set(changed)
    for name in sorted(changed):
        dependents = load_dependents(run, fvm, name)
        unknown = [dependent for dependent in dependents if dependent not in members]
        if unknown:
            raise ToolError(
                f"melos reports dependents outside the workspace for {name!r}: "
                f"{', '.join(sorted(unknown))}"
            )
        selected.update(dependents)

    return Plan(
        mode=IMPACTED,
        event=event,
        changed=tuple(sorted(changed)),
        selected=tuple(sorted(selected)),
        excluded=tuple(sorted(set(members) - selected)),
        reason=(
            f"{len(changed)} directly changed member(s), "
            f"{len(selected - changed)} dependent(s) added"
        ),
        base=base,
        head=head,
    )


def github_output(plan_result: Plan) -> str:
    """The GITHUB_OUTPUT block. An empty packages value means no `--scope`."""
    return f"mode={plan_result.mode}\npackages={plan_result.packages}\n"


def summary_markdown(plan_result: Plan) -> str:
    """The human-readable GITHUB_STEP_SUMMARY block."""
    lines = ["### Impacted unit tests", "", f"Mode: `{plan_result.mode}`"]
    if plan_result.base is not None:
        lines.append(f"Base: `{plan_result.base}` → head: `{plan_result.head}`")
    lines.append(f"Reason: {plan_result.reason}")
    if plan_result.mode != IMPACTED:
        lines.append("")
        lines.append("Every workspace member runs; no `--scope` is applied.")
        return "\n".join(lines) + "\n"
    lines.append("")
    lines.append(f"Directly changed ({len(plan_result.changed)}):")
    lines.append("```")
    lines.append(", ".join(plan_result.changed))
    lines.append("```")
    lines.append(f"Selected ({len(plan_result.selected)}):")
    lines.append("```")
    lines.append(", ".join(plan_result.selected))
    lines.append("```")
    if plan_result.excluded:
        lines.append(f"Excluded ({len(plan_result.excluded)}):")
        lines.append("```")
        lines.append(", ".join(plan_result.excluded))
        lines.append("```")
    else:
        lines.append("Excluded: none")
    return "\n".join(lines) + "\n"


def write_github_output(path: str, plan_result: Plan) -> None:
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(github_output(plan_result))


def write_summary(path: str, plan_result: Plan) -> None:
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(summary_markdown(plan_result))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Select the workspace members whose unit tests a pull request impacts."
        )
    )
    parser.add_argument(
        "--event-name",
        choices=EVENTS,
        default=PULL_REQUEST,
        help="GitHub event name; push and workflow_dispatch always run everything",
    )
    parser.add_argument("--base", help="Base commit or ref of the pull request")
    parser.add_argument("--head", help="Head commit or ref of the pull request")
    parser.add_argument(
        "--output",
        help="File to append the GITHUB_OUTPUT block to (mode, packages)",
    )
    parser.add_argument(
        "--summary", help="File to append the GITHUB_STEP_SUMMARY block to"
    )
    parser.add_argument(
        "--fvm", default="fvm", help="fvm executable used to run melos (default: fvm)"
    )
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
        plan_result = plan(
            event=args.event_name, base=args.base, head=args.head, run=run, fvm=args.fvm
        )
    except UsageError as error:
        print(f"impacted_unit_tests: {error}", file=sys.stderr)
        return 2
    except ToolError as error:
        print(f"impacted_unit_tests: {error}", file=sys.stderr)
        return 1
    try:
        if args.output:
            write_github_output(args.output, plan_result)
        if args.summary:
            write_summary(args.summary, plan_result)
    except OSError as error:
        print(f"impacted_unit_tests: cannot write the outputs: {error}", file=sys.stderr)
        return 1
    json.dump(plan_result.to_json(), out, indent=2, sort_keys=False)
    out.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
