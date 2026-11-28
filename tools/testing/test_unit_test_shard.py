import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "unit_test_shard.sh"
FILES = [f"test/{name}_test.dart" for name in "abcdefg"] + ["test/nested/h_test.dart", "test/helper.dart"]


class UnitTestShardTest(unittest.TestCase):
    def test_access_restores_original_path_without_affecting_other_members(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = root / "original"
            nested = root / "nested"
            original.mkdir()
            nested.mkdir()
            for folder, marker in ((original, "original"), (nested, "nested")):
                fvm = folder / "fvm"
                fvm.write_text(f'#!/bin/sh\nprintf "{marker}\\n"\n')
                fvm.chmod(0o755)
            (root / "test").mkdir()
            (root / "test" / "sample_test.dart").write_text("")
            env = dict(
                os.environ,
                PATH=f"{nested}:{original}:{os.environ['PATH']}",
                ACCESS_UNIT_TEST_PATH=f"{original}:{os.environ['PATH']}",
                TEST_TOTAL_SHARDS="1",
                TEST_SHARD_INDEX="0",
            )
            command = ["bash", str(SCRIPT), "flutter"]
            access = subprocess.run(command, cwd=root, env=dict(env, MELOS_PACKAGE_NAME="access"), text=True, capture_output=True, check=False)
            other = subprocess.run(command, cwd=root, env=dict(env, MELOS_PACKAGE_NAME="other"), text=True, capture_output=True, check=False)
            ordinary = subprocess.run(command, cwd=root, env={k: v for k, v in dict(env, MELOS_PACKAGE_NAME="access").items() if k != "ACCESS_UNIT_TEST_PATH"}, text=True, capture_output=True, check=False)
        self.assertEqual(access.returncode, 0)
        self.assertEqual(access.stdout.strip(), "original")
        self.assertEqual(other.stdout.strip(), "nested")
        self.assertEqual(ordinary.stdout.strip(), "nested")

    def run_shard(self, total, index, files=FILES):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in files:
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_text("")
            # A fake fvm records the test files it is asked to run.
            bin_dir = root / "bin"
            bin_dir.mkdir()
            (bin_dir / "fvm").write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            (bin_dir / "fvm").chmod(0o755)
            env = dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}", TEST_TOTAL_SHARDS=str(total), TEST_SHARD_INDEX=str(index), MELOS_PACKAGE_NAME="member")
            result = subprocess.run(["bash", str(SCRIPT), "flutter", "--reporter=compact"], cwd=root, env=env, text=True, capture_output=True, check=False)
        files_run = [line for line in result.stdout.splitlines() if line.endswith("_test.dart")]
        return result, files_run

    def test_shards_partition_every_test_file(self):
        seen = []
        for index in range(3):
            result, files_run = self.run_shard(3, index)
            self.assertEqual(result.returncode, 0, result.stderr)
            seen += files_run
        self.assertEqual(sorted(seen), sorted(f for f in FILES if f.endswith("_test.dart")))

    def test_unsharded_run_passes_no_file(self):
        result, files_run = self.run_shard(1, 0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(files_run, [])
        self.assertIn("test", result.stdout.splitlines())

    def test_empty_shard_succeeds_without_running_tests(self):
        outputs = [self.run_shard(3, index, files=["test/only_test.dart"]) for index in range(3)]
        self.assertTrue(all(result.returncode == 0 for result, _ in outputs))
        self.assertEqual(sum(len(files_run) for _, files_run in outputs), 1)
        # Without files, `flutter test` would run the whole member: the empty shards must not call the runner at all.
        empty = [result for result, files_run in outputs if not files_run]
        self.assertTrue(all("test" not in result.stdout.splitlines() for result in empty))

    def test_rejects_an_index_outside_the_shards(self):
        result, _ = self.run_shard(3, 3)
        self.assertEqual(result.returncode, 2)

    def test_access_trace_preserves_inventory_output_and_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in FILES:
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_text("")
            bin_dir = root / "bin"
            bin_dir.mkdir()
            fvm = bin_dir / "fvm"
            fvm.write_text(
                '#!/bin/sh\nprintf "%s\\n" "$@" > "$ARGUMENTS"\n'
                'echo "test stdout"\necho "test stderr" >&2\nexit 23\n'
            )
            fvm.chmod(0o755)
            env = dict(
                os.environ,
                PATH=f"{bin_dir}:{os.environ['PATH']}",
                TEST_TOTAL_SHARDS="3",
                TEST_SHARD_INDEX="1",
                MELOS_PACKAGE_NAME="access",
                ARGUMENTS=str(root / "arguments"),
                SENSITIVE_FIXTURE="do-not-print-this-value",
            )
            command = ["bash", str(SCRIPT), "flutter", "--enable-vmservice", "--reporter=compact"]
            plain = subprocess.run(command, cwd=root, env=env, text=True, capture_output=True, check=False)
            plain_args = (root / "arguments").read_text()
            traced = subprocess.run(command, cwd=root, env=dict(env, TRACE_ACCESS_SHARD="1"), text=True, capture_output=True, check=False)
            traced_args = (root / "arguments").read_text()
        self.assertEqual(plain.returncode, 23)
        self.assertEqual(traced.returncode, plain.returncode)
        self.assertEqual(traced_args, plain_args)
        self.assertEqual(traced.stderr, plain.stderr)
        lines = traced.stdout.splitlines()
        markers = [line for line in lines if line.startswith("Access shard trace:")]
        self.assertEqual(len(markers), 2)
        self.assertEqual(markers[0], "Access shard trace: start")
        self.assertRegex(markers[1], r"^Access shard trace: end \(elapsed \d+s, exit 23\)$")
        self.assertEqual("\n".join(line for line in lines if line not in markers) + "\n", plain.stdout)
        self.assertNotIn(env["SENSITIVE_FIXTURE"], traced.stdout + traced.stderr)

    def test_verbose_access_trace_filters_raw_output(self):
        secret = "private-ci-fixture"
        output = "\n".join([
            "[ +464 ms] Running build hooks for linux_x64.",
            f"[  +27 ms] Skipping build for sqlite3 in /{secret}. Last build on today.",
            f"[ +502 ms] Rerunning build for onion in /{secret}. Input changed",
            f"[   +1 ms] Rerunning build for unknown_package in /{secret}. Input changed",
            "[ +137 ms] Running build hooks for linux_x64 done.",
            f"00:00 +0: loading /{secret}",
            f"[        ] Compiling file:///{secret} took 9468ms",
            f"::warning::{secret}",
        ])
        for status in (0, 23):
            with self.subTest(status=status):
                result = subprocess.run(
                    ["python3", str(SCRIPT.with_name("trace_access_hooks.py")), "python3",
                     "-c", f"import sys; print({output!r}, file=sys.stderr); sys.exit({status})"],
                    text=True, capture_output=True, check=False,
                )
                self.assertEqual(result.returncode, status)
                self.assertIn("Skipping build for sqlite3", result.stdout)
                self.assertIn("Rerunning build for onion (input changed)", result.stdout)
                self.assertIn("first test loading", result.stdout)
                self.assertIn("test compilation took 9468ms", result.stdout)
                self.assertNotIn("unknown_package", result.stdout)
                self.assertNotIn(secret, result.stdout + result.stderr)

    def test_real_access_shard_inventory_is_unchanged(self):
        access = SCRIPT.parents[1] / "features" / "access"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fvm = root / "fvm"
            fvm.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$ARGUMENTS"\n')
            fvm.chmod(0o755)
            env = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}", TEST_TOTAL_SHARDS="3", TEST_SHARD_INDEX="1", MELOS_PACKAGE_NAME="access")
            command = ["bash", str(SCRIPT), "flutter", "--enable-vmservice", "--reporter=compact"]
            env["ARGUMENTS"] = str(root / "args")
            plain = subprocess.run(command, cwd=access, env=env, text=True, capture_output=True, check=False)
            plain_args = (root / "args").read_text().splitlines()
            traced = subprocess.run(
                command, cwd=access, env=dict(env, TRACE_ACCESS_SHARD="1", TRACE_ACCESS_HOOKS="1"),
                text=True, capture_output=True, check=False,
            )
            traced_args = (root / "args").read_text().splitlines()
        self.assertEqual(plain.returncode, 0)
        self.assertEqual(traced.returncode, 0)
        self.assertEqual(traced_args.count("-v"), 1)
        self.assertEqual([arg for arg in traced_args if arg != "-v"], plain_args)
        self.assertTrue(any(arg.endswith("_test.dart") for arg in plain_args))

    def test_real_access_unsharded_trace_runs_the_whole_suite(self):
        access = SCRIPT.parents[1] / "features" / "access"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fvm = root / "fvm"
            fvm.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$ARGUMENTS"\n')
            fvm.chmod(0o755)
            env = dict(
                os.environ,
                PATH=f"{root}:{os.environ['PATH']}",
                TEST_TOTAL_SHARDS="1",
                TEST_SHARD_INDEX="0",
                MELOS_PACKAGE_NAME="access",
                ARGUMENTS=str(root / "args"),
            )
            command = ["bash", str(SCRIPT), "flutter", "--enable-vmservice", "--reporter=compact"]
            plain = subprocess.run(command, cwd=access, env=env, text=True, capture_output=True, check=False)
            plain_args = (root / "args").read_text().splitlines()
            traced = subprocess.run(
                command,
                cwd=access,
                env=dict(env, TRACE_ACCESS_SHARD="1", TRACE_ACCESS_HOOKS="1"),
                text=True,
                capture_output=True,
                check=False,
            )
            traced_args = (root / "args").read_text().splitlines()
        self.assertEqual(plain.returncode, 0)
        self.assertEqual(traced.returncode, 0)
        self.assertEqual(traced_args.count("-v"), 1)
        self.assertEqual([arg for arg in traced_args if arg != "-v"], plain_args)
        self.assertFalse(any(arg.endswith("_test.dart") for arg in plain_args))


if __name__ == "__main__":
    unittest.main()
