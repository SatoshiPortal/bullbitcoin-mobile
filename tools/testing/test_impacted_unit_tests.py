"""Tests for tools/impacted_unit_tests.py, without any real git or melos call."""

import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

import impacted_unit_tests as tool  # noqa: E402  (path set up above)

PR_ARGS = ("--event-name", "pull_request", "--base", "base-sha", "--head", "head-sha")

# The chain in these fixtures: bb_mobile depends on app_a, app_a on app_b, app_b
# on app_c, so app_c's dependents are app_a, app_b and bb_mobile. standalone is
# independent: nothing depends on it and it depends on nothing.
CHAIN = {
    "bb_mobile": ".",
    "app_a": "features/app_a",
    "app_b": "features/app_b",
    "app_c": "packages/app_c",
    "standalone": "packages/standalone",
}
DEPENDENTS = {
    "bb_mobile": [],
    "app_a": ["bb_mobile"],
    "app_b": ["app_a", "bb_mobile"],
    "app_c": ["app_b", "app_a", "bb_mobile"],
    "standalone": [],
}


def melos_payload(names, members, root_location="."):
    return json.dumps(
        [
            {
                "name": name,
                "version": "1.0.0",
                "private": True,
                "location": root_location if members[name] == "" else members[name],
                "type": 0,
            }
            for name in names
        ]
    ).encode()


class FakeWorkspace:
    """Answers the tool's git and melos calls from an in-memory workspace."""

    def __init__(self, members=None, dependents=None, diff=(), *, root_location="."):
        self.members = dict(CHAIN if members is None else members)
        self.dependents = dict(DEPENDENTS if dependents is None else dependents)
        self.diff = list(diff)
        self.root_location = root_location
        self.calls = []
        self.members_result = None
        self.dependents_results = {}
        self.git_result = None

    def __call__(self, command):
        command = list(command)
        self.calls.append(command)
        if command[:1] == ["git"]:
            if self.git_result is not None:
                return self.git_result
            return tool.Result(
                0, b"".join(os.fsencode(path) + b"\0" for path in self.diff), b""
            )
        if command[1:5] != ["dart", "run", "melos", "list"]:
            raise AssertionError(f"unexpected command: {command}")
        name = next(
            (arg.split("=", 1)[1] for arg in command if arg.startswith("--depends-on=")),
            None,
        )
        if name is None:
            if self.members_result is not None:
                return self.members_result
            return tool.Result(
                0,
                melos_payload(list(self.members), self.members, self.root_location),
                b"",
            )
        if name in self.dependents_results:
            return self.dependents_results[name]
        return tool.Result(
            0, melos_payload(self.dependents.get(name, []), self.members), b""
        )

    def member_list_calls(self):
        return [
            call
            for call in self.calls
            if call[1:5] == ["dart", "run", "melos", "list"]
            and not any(arg.startswith("--depends-on=") for arg in call)
        ]

    def dependent_calls(self):
        return [
            call
            for call in self.calls
            if any(arg.startswith("--depends-on=") for arg in call)
        ]

    def dependent_names(self):
        return sorted(
            next(
                arg.split("=", 1)[1]
                for arg in call
                if arg.startswith("--depends-on=")
            )
            for call in self.dependent_calls()
        )


def run_main(workspace, *args):
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stderr(err):
        code = tool.main(list(args), run=workspace, stdout=out)
    return code, out.getvalue(), err.getvalue()


class ImpactedSelectionTest(unittest.TestCase):
    def test_chain_tail_change_selects_every_dependent_and_excludes_independent(self):
        workspace = FakeWorkspace(diff=["packages/app_c/lib/src/widget.dart"])
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        payload = json.loads(out)
        self.assertEqual(payload["mode"], "impacted")
        self.assertEqual(payload["changed"], ["app_c"])
        self.assertEqual(payload["selected"], ["app_a", "app_b", "app_c", "bb_mobile"])
        self.assertEqual(payload["excluded"], ["standalone"])
        self.assertEqual(payload["base"], "base-sha")
        self.assertEqual(payload["head"], "head-sha")
        self.assertEqual(payload["event"], "pull_request")
        self.assertTrue(payload["reason"])

    def test_independent_member_change_does_not_select_the_app(self):
        workspace = FakeWorkspace(diff=["packages/standalone/lib/standalone.dart"])
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        payload = json.loads(out)
        self.assertEqual(payload["changed"], ["standalone"])
        self.assertEqual(payload["selected"], ["standalone"])
        self.assertEqual(
            payload["excluded"], ["app_a", "app_b", "app_c", "bb_mobile"]
        )

    def test_independent_and_chain_change_selects_every_member(self):
        workspace = FakeWorkspace(
            diff=[
                "packages/app_c/lib/src/widget.dart",
                "packages/standalone/lib/standalone.dart",
            ]
        )
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        payload = json.loads(out)
        self.assertEqual(payload["changed"], ["app_c", "standalone"])
        self.assertEqual(
            payload["selected"], ["app_a", "app_b", "app_c", "bb_mobile", "standalone"]
        )
        self.assertEqual(payload["excluded"], [])
        self.assertEqual(
            out.count('"selected"'), 1, "selected must be reported once"
        )

    def test_member_pubspec_change_selects_that_member(self):
        workspace = FakeWorkspace(diff=["features/app_a/pubspec.yaml"])
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        payload = json.loads(out)
        self.assertEqual(payload["changed"], ["app_a"])
        self.assertEqual(payload["selected"], ["app_a", "bb_mobile"])

    def test_root_source_paths_select_the_root_member(self):
        for path in (
            "lib/main.dart",
            "test/architecture/imports_test.dart",
            "integration_test/all_test.dart",
            "localization/app_en.arb",
            "assets/images/logo.png",
        ):
            with self.subTest(path=path):
                workspace = FakeWorkspace(diff=[path])
                code, out, err = run_main(workspace, *PR_ARGS)
                self.assertEqual(code, 0, err)
                payload = json.loads(out)
                self.assertEqual(payload["changed"], ["bb_mobile"])
                self.assertEqual(payload["selected"], ["bb_mobile"])
                self.assertIn("app_c", payload["excluded"])

    def test_child_member_file_never_lands_on_the_root_member(self):
        workspace = FakeWorkspace(diff=["features/app_a/lib/src/x.dart"])
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        payload = json.loads(out)
        self.assertEqual(payload["changed"], ["app_a"])
        self.assertEqual(payload["selected"], ["app_a", "bb_mobile"])

    def test_nested_members_use_the_longest_location(self):
        workspace = FakeWorkspace(
            members={
                "lead": ".",
                "send": "features/send",
                "send_extras": "features/send/extras",
            },
            dependents={"lead": [], "send": [], "send_extras": []},
            diff=["features/send/extras/lib/extras.dart"],
        )
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        payload = json.loads(out)
        self.assertEqual(payload["changed"], ["send_extras"])
        self.assertEqual(payload["selected"], ["send_extras"])

    def test_location_spelled_as_empty_string_is_the_root(self):
        workspace = FakeWorkspace(diff=["features/app_a/lib/src/x.dart"])
        workspace.members_result = tool.Result(
            0,
            json.dumps(
                [
                    {"name": "bb_mobile", "location": ""},
                    {"name": "app_a", "location": "./features/app_a/"},
                ]
            ).encode(),
            b"",
        )
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        self.assertEqual(json.loads(out)["changed"], ["app_a"])

    def test_deleted_file_still_selects_its_member(self):
        workspace = FakeWorkspace(diff=["packages/app_c/lib/gone.dart"])
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        self.assertIn("app_c", json.loads(out)["changed"])


class FallbackTest(unittest.TestCase):
    FULL_PATHS = (
        "pubspec.yaml",
        "pubspec.lock",
        "features/app_a/pubspec.lock",
        "melos.yaml",
        ".fvmrc",
        "makefile",
        "analysis_options.yaml",
        "Containerfile.app",
        "README.md",
        "docs/architecture.md",
        ".github/workflows/analyze_and_test.yml",
        "tools/unit_test_shard.sh",
        "tools/pr_governance/custody.js",
        "libfoo/unrelated.dart",
        "other/outside.dart",
        "../outside.dart",
        "/etc/passwd",
    )
    NATIVE_PATHS = (
        "android/app/build.gradle",
        "ios/Podfile",
        "linux/CMakeLists.txt",
        "macos/Podfile",
        "windows/CMakeLists.txt",
        "packages/rust_bindings/hook/build.dart",
        "packages/rust_bindings/rust/src/lib.rs",
        "features/app_a/android/src/main/kotlin/Plugin.kt",
    )

    def test_global_root_and_unknown_paths_force_the_full_suite(self):
        for path in self.FULL_PATHS:
            with self.subTest(path=path):
                workspace = FakeWorkspace(diff=[path])
                code, out, err = run_main(workspace, *PR_ARGS)
                self.assertEqual(code, 0, err)
                payload = json.loads(out)
                self.assertEqual(payload["mode"], "full")
                self.assertEqual(payload["changed"], [])
                self.assertEqual(
                    payload["selected"],
                    ["app_a", "app_b", "app_c", "bb_mobile", "standalone"],
                )
                self.assertEqual(payload["excluded"], [])
                self.assertTrue(payload["reason"])
                self.assertEqual(workspace.dependent_calls(), [])

    def test_native_and_hook_paths_force_the_full_suite(self):
        for path in self.NATIVE_PATHS:
            with self.subTest(path=path):
                workspace = FakeWorkspace(diff=[path])
                code, out, err = run_main(workspace, *PR_ARGS)
                self.assertEqual(code, 0, err)
                payload = json.loads(out)
                self.assertEqual(payload["mode"], "full")
                touched = set(path.split("/")) & set(tool.NATIVE_SEGMENTS)
                self.assertTrue(
                    any(segment in payload["reason"] for segment in touched),
                    f"{path}: {payload['reason']}",
                )
                self.assertEqual(workspace.dependent_calls(), [])

    def test_one_unattributable_path_forces_full_even_next_to_a_member(self):
        workspace = FakeWorkspace(
            diff=["features/app_a/lib/src/x.dart", "pubspec.lock"]
        )
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        self.assertEqual(json.loads(out)["mode"], "full")

    def test_empty_diff_forces_the_full_suite(self):
        workspace = FakeWorkspace(diff=[])
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        payload = json.loads(out)
        self.assertEqual(payload["mode"], "full")
        self.assertIn("no file differs", payload["reason"])
        self.assertEqual(workspace.dependent_calls(), [])


class OutputTest(unittest.TestCase):
    def test_output_file_json_and_summary_for_an_impacted_run(self):
        workspace = FakeWorkspace(diff=["packages/app_c/lib/src/widget.dart"])
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "github_output"
            summary = Path(directory) / "github_summary"
            code, out, err = run_main(
                workspace, *PR_ARGS, "--output", str(output), "--summary", str(summary)
            )
            self.assertEqual(code, 0, err)
            self.assertEqual(
                output.read_text(),
                "mode=impacted\npackages=app_a,app_b,app_c,bb_mobile\n",
            )
            rendered = summary.read_text()
        payload = json.loads(out)
        self.assertEqual(payload["mode"], "impacted")
        self.assertEqual(payload["changed"], ["app_c"])
        self.assertEqual(payload["selected"], ["app_a", "app_b", "app_c", "bb_mobile"])
        self.assertEqual(payload["excluded"], ["standalone"])
        self.assertIn("### Impacted unit tests", rendered)
        self.assertIn("Mode: `impacted`", rendered)
        self.assertIn("Base: `base-sha` → head: `head-sha`", rendered)
        self.assertIn("Directly changed (1):", rendered)
        self.assertIn("app_c", rendered)
        self.assertIn("Selected (4):", rendered)
        self.assertIn("Excluded (1):", rendered)
        self.assertIn("standalone", rendered)
        self.assertNotIn("Every workspace member runs", rendered)

    def test_full_run_output_leaves_the_scope_empty(self):
        workspace = FakeWorkspace(diff=["pubspec.yaml"])
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "github_output"
            summary = Path(directory) / "github_summary"
            code, out, err = run_main(
                workspace, *PR_ARGS, "--output", str(output), "--summary", str(summary)
            )
            self.assertEqual(code, 0, err)
            self.assertEqual(output.read_text(), "mode=full\npackages=\n")
            rendered = summary.read_text()
        payload = json.loads(out)
        self.assertEqual(payload["mode"], "full")
        self.assertIn("Mode: `full`", rendered)
        self.assertIn("Every workspace member runs", rendered)
        self.assertNotIn("Excluded", rendered)

    def test_output_is_appended_not_truncated(self):
        workspace = FakeWorkspace(diff=["pubspec.yaml"])
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "github_output"
            output.write_text("previous=value\n")
            code, out, err = run_main(workspace, *PR_ARGS, "--output", str(output))
            self.assertEqual(code, 0, err)
            self.assertTrue(output.read_text().startswith("previous=value\n"))
            self.assertIn("mode=full\n", output.read_text())

    def test_json_goes_to_stdout_without_an_output_file(self):
        workspace = FakeWorkspace(diff=["features/app_a/pubspec.yaml"])
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        self.assertEqual(json.loads(out)["mode"], "impacted")
        self.assertTrue(out.endswith("\n"))


class NonPullRequestTest(unittest.TestCase):
    def test_push_runs_everything_without_asking_git_or_melos(self):
        for event in ("push", "workflow_dispatch"):
            with self.subTest(event=event):
                workspace = FakeWorkspace(diff=["packages/app_c/lib/src/x.dart"])
                code, out, err = run_main(workspace, "--event-name", event)
                self.assertEqual(code, 0, err)
                payload = json.loads(out)
                self.assertEqual(payload["mode"], "full")
                self.assertEqual(payload["changed"], [])
                self.assertEqual(payload["selected"], [])
                self.assertEqual(payload["excluded"], [])
                self.assertNotIn("base", payload)
                self.assertNotIn("head", payload)
                self.assertTrue(payload["reason"])
                self.assertEqual(workspace.calls, [])

    def test_push_output_keeps_the_scope_empty(self):
        workspace = FakeWorkspace()
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "github_output"
            code, out, err = run_main(
                workspace, "--event-name", "push", "--output", str(output)
            )
            self.assertEqual(code, 0, err)
            self.assertEqual(output.read_text(), "mode=full\npackages=\n")
        self.assertEqual(workspace.calls, [])


class CommandShapeTest(unittest.TestCase):
    def test_melos_commands_match_the_documented_shape(self):
        workspace = FakeWorkspace(diff=["features/app_a/lib/src/x.dart"])
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        self.assertEqual(
            workspace.member_list_calls(),
            [["fvm", "dart", "run", "melos", "list", "--json", "--relative"]],
        )
        self.assertEqual(
            workspace.dependent_calls(),
            [
                [
                    "fvm",
                    "dart",
                    "run",
                    "melos",
                    "list",
                    "--depends-on=app_a",
                    "--include-dependents",
                    "--json",
                    "--relative",
                ]
            ],
        )
        for call in workspace.calls:
            self.assertNotIn("--diff", call, "the native --diff filter is not used")
            self.assertNotIn("--graph", call)
            self.assertNotIn("--long", call)

    def test_git_command_targets_the_pull_request_range(self):
        workspace = FakeWorkspace(diff=["features/app_a/lib/src/x.dart"])
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        self.assertEqual(
            workspace.calls[1],
            [
                "git",
                "diff",
                "--name-only",
                "--no-renames",
                "-z",
                "base-sha...head-sha",
                "--",
            ],
        )

    def test_rename_reports_old_and_new_paths(self):
        workspace = FakeWorkspace(
            diff=[
                "packages/app_c/lib/src/old_name.dart",
                "features/app_a/lib/src/new_name.dart",
            ]
        )
        self.assertEqual(
            tool.changed_files(workspace, "base-sha", "head-sha"),
            [
                "packages/app_c/lib/src/old_name.dart",
                "features/app_a/lib/src/new_name.dart",
            ],
        )

    def test_dependents_are_queried_once_per_changed_member(self):
        workspace = FakeWorkspace(
            diff=["features/app_a/lib/src/x.dart", "packages/standalone/lib/s.dart"]
        )
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        self.assertEqual(workspace.dependent_names(), ["app_a", "standalone"])
        self.assertEqual(len(workspace.member_list_calls()), 1)

    def test_fvm_option_selects_the_executable(self):
        workspace = FakeWorkspace(diff=["features/app_a/lib/src/x.dart"])
        code, out, err = run_main(workspace, *PR_ARGS, "--fvm", "/opt/fvm/bin/fvm")
        self.assertEqual(code, 0, err)
        self.assertTrue(workspace.calls[0][0] == "/opt/fvm/bin/fvm")
        self.assertTrue(workspace.calls[0][:5] == [
            "/opt/fvm/bin/fvm",
            "dart",
            "run",
            "melos",
            "list",
        ])


class FailureTest(unittest.TestCase):
    def test_missing_base_or_head_is_a_usage_error(self):
        for args in (
            ("--event-name", "pull_request", "--head", "head-sha"),
            ("--event-name", "pull_request", "--base", "base-sha"),
            ("--event-name", "pull_request"),
        ):
            with self.subTest(args=args):
                workspace = FakeWorkspace(diff=["lib/main.dart"])
                code, out, err = run_main(workspace, *args)
                self.assertEqual(code, 2)
                self.assertEqual(out, "")
                self.assertIn("--base", err)
                self.assertEqual(workspace.calls, [])

    def test_git_failure_is_an_error_and_never_a_full_run(self):
        workspace = FakeWorkspace(diff=["lib/main.dart"])
        workspace.git_result = tool.Result(128, b"", b"fatal: bad revision")
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertIn("git diff", err)
        self.assertIn("bad revision", err)

    def test_melos_members_failure_is_an_error(self):
        workspace = FakeWorkspace(diff=["lib/main.dart"])
        workspace.members_result = tool.Result(1, b"", b"melos exploded")
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertIn("melos exploded", err)

    def test_melos_dependents_failure_is_an_error(self):
        workspace = FakeWorkspace(diff=["features/app_a/lib/src/x.dart"])
        workspace.dependents_results["app_a"] = tool.Result(1, b"", b"no workspace")
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertIn("--depends-on=app_a", err)

    def test_non_json_melos_output_is_an_error(self):
        for payload in (b"", b"not json at all"):
            with self.subTest(payload=payload):
                workspace = FakeWorkspace(diff=["lib/main.dart"])
                workspace.members_result = tool.Result(0, payload, b"")
                code, out, err = run_main(workspace, *PR_ARGS)
                self.assertEqual(code, 1)
                self.assertEqual(out, "")

    def test_json_object_instead_of_array_is_an_error(self):
        workspace = FakeWorkspace(diff=["lib/main.dart"])
        workspace.members_result = tool.Result(0, b'{"name": "bb_mobile"}', b"")
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 1)
        self.assertEqual(out, "")

    def test_trailing_garbage_after_the_json_array_is_an_error(self):
        workspace = FakeWorkspace(diff=["lib/main.dart"])
        workspace.members_result = tool.Result(
            0, b'[{"name": "bb_mobile", "location": "."}] trailing', b""
        )
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 1)
        self.assertEqual(out, "")

    def test_entry_without_location_is_an_error(self):
        workspace = FakeWorkspace(diff=["lib/main.dart"])
        workspace.members_result = tool.Result(0, b'[{"name": "bb_mobile"}]', b"")
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 1)
        self.assertIn("location", err)

    def test_duplicate_member_name_is_an_error(self):
        workspace = FakeWorkspace(diff=["lib/main.dart"])
        workspace.members_result = tool.Result(
            0,
            json.dumps(
                [
                    {"name": "bb_mobile", "location": "."},
                    {"name": "twice", "location": "features/twice"},
                    {"name": "twice", "location": "packages/twice"},
                ]
            ).encode(),
            b"",
        )
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 1)
        self.assertIn("twice", err)

    def test_duplicate_location_is_an_error(self):
        workspace = FakeWorkspace(diff=["lib/main.dart"])
        workspace.members_result = tool.Result(
            0,
            json.dumps(
                [
                    {"name": "bb_mobile", "location": "."},
                    {"name": "one", "location": "features/one"},
                    {"name": "two", "location": "features/one"},
                ]
            ).encode(),
            b"",
        )
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 1)
        self.assertIn("same location", err)

    def test_workspace_without_a_root_is_an_error(self):
        workspace = FakeWorkspace(diff=["lib/main.dart"])
        workspace.members_result = tool.Result(
            0, b'[{"name": "app_a", "location": "features/app_a"}]', b""
        )
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 1)
        self.assertIn("exactly one root", err)

    def test_workspace_with_two_roots_is_an_error(self):
        workspace = FakeWorkspace(diff=["lib/main.dart"])
        workspace.members_result = tool.Result(
            0,
            json.dumps(
                [
                    {"name": "one", "location": "."},
                    {"name": "two", "location": "./"},
                ]
            ).encode(),
            b"",
        )
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 1)
        self.assertIn("exactly one root", err)

    def test_unusable_melos_location_is_an_error(self):
        for location in ("/absolute/path", "../outside"):
            with self.subTest(location=location):
                workspace = FakeWorkspace(diff=["lib/main.dart"])
                workspace.members_result = tool.Result(
                    0,
                    json.dumps(
                        [
                            {"name": "bb_mobile", "location": "."},
                            {"name": "odd", "location": location},
                        ]
                    ).encode(),
                    b"",
                )
                code, out, err = run_main(workspace, *PR_ARGS)
                self.assertEqual(code, 1)
                self.assertIn("unusable location", err)

    def test_dependent_outside_the_workspace_is_an_error(self):
        workspace = FakeWorkspace(diff=["features/app_a/lib/src/x.dart"])
        workspace.dependents_results["app_a"] = tool.Result(
            0, b'[{"name": "ghost", "location": "packages/ghost"}]', b""
        )
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertIn("ghost", err)

    def test_unwritable_output_file_is_an_error(self):
        workspace = FakeWorkspace(diff=["lib/main.dart"])
        with tempfile.TemporaryDirectory() as directory:
            blocked = Path(directory) / "blocked"
            blocked.mkdir()
            code, out, err = run_main(
                workspace, *PR_ARGS, "--output", str(blocked)
            )
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertIn("cannot write", err)

    def test_missing_executable_is_a_tool_error(self):
        with self.assertRaises(tool.ToolError) as raised:
            tool.run_subprocess(["impacted-unit-tests-no-such-binary", "--version"])
        self.assertIn("cannot run", str(raised.exception))


class PayloadToleranceTest(unittest.TestCase):
    def test_warning_prefix_before_the_json_array_is_skipped(self):
        workspace = FakeWorkspace(
            members={"bb_mobile": ".", "leaf": "packages/leaf"},
            dependents={"bb_mobile": [], "leaf": ["bb_mobile"]},
            diff=["packages/leaf/lib/leaf.dart"],
        )
        workspace.members_result = tool.Result(
            0,
            b'Warning: something about the workspace\n'
            b'[{"name": "bb_mobile", "location": "."},'
            b' {"name": "leaf", "location": "packages/leaf"}]\n',
            b"",
        )
        code, out, err = run_main(workspace, *PR_ARGS)
        self.assertEqual(code, 0, err)
        self.assertIn("skipped", err)
        payload = json.loads(out)
        self.assertEqual(payload["changed"], ["leaf"])
        self.assertEqual(payload["selected"], ["bb_mobile", "leaf"])


class AttributeTest(unittest.TestCase):
    def test_attribute_reports_the_reason_for_every_fallback(self):
        members = {"bb_mobile": "", "send": "features/send"}
        for path in ("pubspec.yaml", "android/app/build.gradle", "../escape.dart"):
            with self.subTest(path=path):
                attribution = tool.attribute(path, members, "bb_mobile")
                self.assertIsNone(attribution.member)
                self.assertTrue(attribution.reason)

    def test_attribute_maps_prefix_boundaries_exactly(self):
        members = {"bb_mobile": "", "send": "features/send"}
        self.assertEqual(
            tool.attribute("features/send/lib/x.dart", members, "bb_mobile").member,
            "send",
        )
        # A sibling directory that merely starts with the member name is not the
        # member, and not an attributable root path either, so it forces full.
        sibling = tool.attribute("features/sender/lib/x.dart", members, "bb_mobile")
        self.assertIsNone(sibling.member)
        self.assertTrue(sibling.reason)


if __name__ == "__main__":
    unittest.main()
