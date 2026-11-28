"""Tests for the dynamic per-member GitHub Actions unit-test matrix."""

import contextlib
import io
import json
import re
import tempfile
import unittest
from pathlib import Path

from tools import impacted_unit_tests as selector
from tools import unit_test_matrix as tool

MEMBERS = {
    "bb_mobile": ".",
    "exchange": "packages/exchange",
    "secrets": "packages/secrets",
    "sync": "packages/sync",
    "without_tests": "packages/without_tests",
}


REPOSITORY = Path(__file__).resolve().parents[2]
WORKFLOW = (REPOSITORY / ".github/workflows/analyze_and_test.yml").read_text()


class MatrixWorkspace(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.workspace = Path(self.temporary.name)
        for name in ("bb_mobile", "exchange", "secrets", "sync"):
            (self.workspace / MEMBERS[name] / "test").mkdir(parents=True)
        (self.workspace / MEMBERS["without_tests"]).mkdir(parents=True)

    def tearDown(self):
        self.temporary.cleanup()

    def jobs(self, mode=tool.IMPACTED, packages="exchange"):
        return tool.build_jobs(
            mode=mode,
            packages=packages,
            members=MEMBERS,
            workspace=self.workspace,
        )

    def test_full_mode_shards_only_the_root_application(self):
        jobs, multi_view = self.jobs(mode=tool.FULL, packages="")
        self.assertTrue(multi_view)
        self.assertEqual(len(jobs), 6)
        self.assertEqual(
            [(job["package"], job["shard"], job["shards"]) for job in jobs[:3]],
            [("bb_mobile", shard, 3) for shard in range(3)],
        )
        self.assertNotIn("without_tests", {job["package"] for job in jobs})
        for job in jobs:
            self.assertTrue(job["run"])

    def test_impacted_mode_has_one_rerunnable_job_per_selected_member(self):
        jobs, multi_view = self.jobs(packages="exchange,without_tests")
        self.assertFalse(multi_view)
        self.assertEqual(
            jobs,
            [
                {
                    "name": "Unit tests / exchange",
                    "package": "exchange",
                    "run": True,
                    "shard": 0,
                    "shards": 1,
                }
            ],
        )

    def test_empty_impacted_scope_produces_an_explicit_noop(self):
        jobs, multi_view = self.jobs(packages="")
        self.assertFalse(multi_view)
        self.assertEqual(len(jobs), 1)
        self.assertFalse(jobs[0]["run"])
        self.assertEqual(jobs[0]["name"], "Unit tests / no impacted test suites")

    def test_selected_member_without_tests_can_still_require_multi_view(self):
        jobs, multi_view = self.jobs(packages="without_tests,sync")
        self.assertTrue(multi_view)
        self.assertEqual(len(jobs), 1)
        self.assertEqual(jobs[0]["package"], "sync")

    def test_selected_secrets_and_sync_have_one_separate_multi_view_gate(self):
        _, multi_view = self.jobs(packages="secrets,sync")
        self.assertTrue(multi_view)

    def test_invalid_input_never_becomes_an_empty_or_silent_full_run(self):
        cases = (
            (tool.FULL, "exchange", "full mode"),
            (tool.IMPACTED, "exchange,,sync", "empty name"),
            (tool.IMPACTED, "exchange,exchange", "duplicate"),
            (tool.IMPACTED, "ghost", "unknown members"),
            ("other", "exchange", "unsupported"),
        )
        for mode, packages, message in cases:
            with self.subTest(mode=mode, packages=packages):
                with self.assertRaisesRegex(tool.ToolError, message):
                    self.jobs(mode=mode, packages=packages)

    def test_github_output_uses_one_compact_json_include_array(self):
        jobs, _ = self.jobs(packages="exchange")
        lines = tool.github_output(jobs, False).splitlines()
        self.assertEqual(lines[0], "jobs<<BULL_UNIT_TEST_MATRIX")
        self.assertEqual(json.loads(lines[1]), jobs)
        self.assertEqual(lines[1], json.dumps(jobs, separators=(",", ":")))
        self.assertEqual(lines[2:], ["BULL_UNIT_TEST_MATRIX", "multi_view=false"])

    def test_main_uses_the_live_melos_members_and_writes_outputs(self):
        payload = json.dumps(
            [
                {"name": name, "location": location}
                for name, location in MEMBERS.items()
            ]
        ).encode()
        calls = []

        def run(command):
            calls.append(command)
            return selector.Result(0, payload, b"")

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "github-output"
            stdout = io.StringIO()
            stderr = io.StringIO()
            with contextlib.redirect_stderr(stderr):
                code = tool.main(
                    [
                        "--mode",
                        tool.IMPACTED,
                        "--packages",
                        "exchange",
                        "--workspace",
                        str(self.workspace),
                        "--output",
                        str(output),
                    ],
                    run=run,
                    stdout=stdout,
                )
            text = output.read_text()
        self.assertEqual(code, 0, stderr.getvalue())
        self.assertEqual(len(calls), 1)
        self.assertIn("melos", calls[0])
        self.assertIn('"package": "exchange"', stdout.getvalue())
        self.assertIn("multi_view=false", text)


class WorkflowContractTest(unittest.TestCase):
    def test_dynamic_matrix_is_independent_and_root_subshards_are_explicit(self):
        self.assertIn(
            "matrix:\n        include: ${{ fromJSON(needs.prepare-x64.outputs.unit-test-jobs) }}",
            WORKFLOW,
        )
        self.assertIn("strategy:\n      fail-fast: false", WORKFLOW)
        self.assertIn("TEST_RUN_MULTIVIEW=0", WORKFLOW)
        self.assertIn("TEST_TOTAL_SHARDS=${{ matrix.shards }}", WORKFLOW)
        self.assertIn("TRACE_ACCESS_SHARD: ${{ matrix.package == 'access' && '1' || '0' }}", WORKFLOW)

    def test_every_matrix_expression_resolves_against_a_generated_job(self):
        unit_tests = WORKFLOW.split("  unit-tests:\n", 1)[1].split("  unit-multiview:\n", 1)[0]
        paths = set(re.findall(r"\bmatrix\.([A-Za-z_][A-Za-z0-9_.]*)", unit_tests))
        self.assertEqual(paths, {"name", "package", "run", "shard", "shards"})
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            (workspace / "test").mkdir()
            jobs, _ = tool.build_jobs(
                mode=tool.IMPACTED,
                packages="bb_mobile",
                members={"bb_mobile": "."},
                workspace=workspace,
            )
        for job in jobs:
            for path in paths:
                with self.subTest(job=job["name"], path=path):
                    value = job
                    for segment in path.split("."):
                        self.assertIsInstance(value, dict)
                        self.assertIn(segment, value)
                        value = value[segment]
                    self.assertIsNotNone(value)

    def test_static_checks_no_longer_run_an_aggregate_unit_shard(self):
        checks = WORKFLOW.split("  checks:\n", 1)[1].split("  # Each selected", 1)[0]
        self.assertNotIn("make unit-test ", checks)
        self.assertIn("run: make aot-check", checks)

    def test_gate_depends_on_preparation_and_every_unit_test_result(self):
        self.assertIn(
            "needs: [classification, action-pins, readiness, prepare-x64, checks, unit-tests, unit-multiview, integration]",
            WORKFLOW,
        )
        gate = WORKFLOW.split("  ci:\n", 1)[1]
        for name in (
            "PREPARE_RESULT",
            "UNIT_TESTS_RESULT",
            "MULTI_VIEW_RESULT",
            "MULTI_VIEW_REQUIRED",
            "INTEGRATION_RESULT",
        ):
            self.assertIn(name, gate)

    def test_integration_remains_unfiltered(self):
        integration = WORKFLOW.split("  integration:\n", 1)[1].split("  ci:\n", 1)[0]
        self.assertIn("runs-on: ubuntu-24.04-arm", integration)
        self.assertIn("make integration-test", integration)
        self.assertNotIn("unit-test-packages", integration)


if __name__ == "__main__":
    unittest.main()
