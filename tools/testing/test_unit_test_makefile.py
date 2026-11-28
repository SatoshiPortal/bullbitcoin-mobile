import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]


class UnitTestMakefileTest(unittest.TestCase):
    def run_make(self, *, packages=None, total=3, index=0):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fvm = root / "fvm"
            fvm.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            fvm.chmod(0o755)
            env = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}")
            env.pop("TEST_PACKAGES", None)
            if packages is not None:
                env["TEST_PACKAGES"] = packages
            result = subprocess.run(
                [
                    "make",
                    "unit-test",
                    f"TEST_TOTAL_SHARDS={total}",
                    f"TEST_SHARD_INDEX={index}",
                ],
                cwd=REPOSITORY,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.splitlines()

    def test_impacted_scope_reaches_both_melos_runners(self):
        lines = self.run_make(packages="bull_exchange,settings,wizard,bb_mobile")
        self.assertEqual(lines.count("--scope=bull_exchange,settings,wizard,bb_mobile"), 2)
        self.assertEqual(lines.count("--fail-fast"), 2)
        self.assertEqual(lines.count("--flutter"), 1)
        self.assertEqual(lines.count("--no-flutter"), 1)

    def test_full_suite_keeps_melos_unscoped(self):
        lines = self.run_make(total=1)
        self.assertFalse(any(line.startswith("--scope=") for line in lines))
        self.assertEqual(lines.count("--dart-define=BULL_MULTI_VIEW=true"), 2)

    def test_unrelated_selection_skips_multiple_view_suites(self):
        lines = self.run_make(packages="bull_exchange,settings,wizard,bb_mobile")
        self.assertEqual(lines.count("--dart-define=BULL_MULTI_VIEW=true"), 0)
        self.assertIn("Skipping multiple-view tests: neither secrets nor sync is impacted.", lines)

    def test_multiple_view_suites_run_once_in_shard_zero(self):
        zero = self.run_make(packages="secrets,sync,bb_mobile", index=0)
        one = self.run_make(packages="secrets,sync,bb_mobile", index=1)
        self.assertEqual(zero.count("--dart-define=BULL_MULTI_VIEW=true"), 2)
        self.assertEqual(one.count("--dart-define=BULL_MULTI_VIEW=true"), 0)
        self.assertIn("Skipping multiple-view tests: they run only in shard 0.", one)


if __name__ == "__main__":
    unittest.main()
