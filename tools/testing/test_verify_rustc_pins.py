import os
import re
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "verify_rustc_pins.sh"
# Distinct fixture versions exercise per-library compiler selection.
SDK_RUST = "1.100.0"
PAYJOIN_RUST = "1.85.1"
LIBRARIES = {
    "librust_lib_onion.so": SDK_RUST,
    "librust_lib_bull_sdk.so": SDK_RUST,
    "libbdk_dart_ffi.so": SDK_RUST,
    "libpayjoin_ffi_wrapper.so": PAYJOIN_RUST,
}


class VerifyRustcPinsTest(unittest.TestCase):
    def check_apk(self, *, abis=("arm64-v8a",), changed=None, expected_abis=None, require_scuttle=False, via_make=False):
        files = {
            f"lib/{abi}/{name}": f"rustc version {version}\n".encode()
            for abi in abis
            for name, version in LIBRARIES.items()
        }
        files.update(changed or {})
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "app.apk"
            with zipfile.ZipFile(apk, "w") as archive:
                for path, content in files.items():
                    if content is not None:
                        archive.writestr(path, content)
            command = ["bash", str(SCRIPT), *(["--require-scuttle"] if require_scuttle else []), str(apk), SDK_RUST, PAYJOIN_RUST, *(expected_abis or abis)]
            if via_make:
                container = Path(directory) / "container"
                container.write_text('#!/bin/sh\nprintf "rustc %s (fixture)\\n" "$6"\n')
                container.chmod(0o700)
                command = ["make", "--no-print-directory", "verify-rustc-pins", f"CONTAINER={container}", f"APK={apk}"]
            result = subprocess.run(
                command,
                text=True,
                capture_output=True,
                check=False,
            )
        return result

    def test_android_verification_requires_the_app_scuttle_dependency(self):
        root = SCRIPT.parents[1]
        plan = subprocess.run(
            ["make", "-n", "android", "release"], cwd=root,
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(plan.returncode, 0, plan.stderr)
        self.assertIn('verify-rustc-pins APK=', plan.stdout)
        missing = self.check_apk(via_make=True)
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("Missing tracked Rust library: arm64-v8a/librust_lib_scuttle.so", missing.stderr)
        present = self.check_apk(
            via_make=True,
            changed={"lib/arm64-v8a/librust_lib_scuttle.so": f"rustc version {SDK_RUST}\n".encode()},
        )
        self.assertEqual(present.returncode, 0, present.stdout + present.stderr)

    def test_accepts_arm64_only_when_requested(self):
        self.assertEqual(self.check_apk().returncode, 0)

    def test_allows_non_rust_libraries_in_extra_abis(self):
        result = self.check_apk(
            changed={
                "lib/armeabi-v7a/libsqlite3.so": b"native library",
                "lib/x86_64/libsqlite3.so": b"native library",
            }
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_rust_library_in_extra_abi(self):
        result = self.check_apk(
            changed={"lib/x86_64/librust_lib_onion.so": b"rustc version 1.100.0\n"}
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unexpected ABI", result.stderr)

    def test_accepts_all_release_abis(self):
        self.assertEqual(
            self.check_apk(abis=("armeabi-v7a", "arm64-v8a", "x86_64")).returncode,
            0,
        )

    def test_rejects_missing_expected_abi(self):
        result = self.check_apk(expected_abis=("arm64-v8a", "armeabi-v7a"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing expected ABI", result.stderr)

    def test_rejects_missing_library(self):
        result = self.check_apk(changed={"lib/arm64-v8a/librust_lib_onion.so": None})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing tracked Rust library", result.stderr)

    def test_rejects_old_bdk_compiler(self):
        result = self.check_apk(
            changed={"lib/arm64-v8a/libbdk_dart_ffi.so": b"rustc version 1.85.1\n"}
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unexpected rustc markers", result.stderr)

    def test_preserves_official_payjoin_compiler(self):
        result = self.check_apk(
            changed={"lib/arm64-v8a/libpayjoin_ffi_wrapper.so": b"rustc version 1.100.0\n"}
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unexpected rustc markers", result.stderr)

    def test_rejects_missing_marker(self):
        result = self.check_apk(changed={"lib/arm64-v8a/librust_lib_onion.so": b"no version"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No rustc version marker", result.stderr)

    def test_rejects_multiple_versions(self):
        result = self.check_apk(
            changed={"lib/arm64-v8a/librust_lib_onion.so": b"rustc version 1.100.0\nrustc version 1.97.1\n"}
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unexpected rustc markers", result.stderr)

    def test_rejects_unknown_rust_library(self):
        result = self.check_apk(changed={"lib/arm64-v8a/libnew.so": b"rustc version 1.100.0\n"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Untracked Rust library", result.stderr)

    def test_required_scuttle_is_checked_in_every_expected_abi(self):
        abis = ("arm64-v8a", "x86_64")
        for missing in (None, "arm64-v8a", "x86_64"):
            with self.subTest(missing=missing):
                result = self.check_apk(
                    abis=abis,
                    changed={f"lib/{abi}/librust_lib_scuttle.so": f"rustc version {SDK_RUST}\n".encode() for abi in abis if abi != missing},
                    require_scuttle=True,
                )
                if missing is None:
                    self.assertEqual(result.returncode, 0, result.stderr)
                else:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(f"Missing tracked Rust library: {missing}/librust_lib_scuttle.so", result.stderr)

    def test_rejects_wrong_missing_or_mixed_scuttle_markers(self):
        for markers, diagnostic in (
            (b"rustc version 1.90.0\n", "Unexpected rustc markers"),
            (b"no version", "No rustc version marker"),
            (f"rustc version {SDK_RUST}\nrustc version 1.90.0\n".encode(), "Unexpected rustc markers"),
        ):
            with self.subTest(markers=markers):
                result = self.check_apk(changed={"lib/arm64-v8a/librust_lib_scuttle.so": markers})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stderr)

    def test_scuttle_uses_the_sdk_compiler_pin(self):
        library = "lib/arm64-v8a/librust_lib_scuttle.so"
        correct = self.check_apk(changed={library: f"rustc version {SDK_RUST}\n".encode()})
        self.assertEqual(correct.returncode, 0, correct.stderr)
        self.assertIn(f"librust_lib_scuttle.so: rustc {SDK_RUST}", correct.stdout)
        wrong = self.check_apk(changed={library: b"rustc version 1.90.0\n"})
        self.assertNotEqual(wrong.returncode, 0)
        self.assertIn("Unexpected rustc markers", wrong.stderr)

    def test_rejects_extra_abi_scuttle_without_marker(self):
        result = self.check_apk(changed={"lib/x86_64/librust_lib_scuttle.so": b"no version"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Tracked Rust library in unexpected ABI", result.stderr)

    def test_bare_required_scuttle_flag_reports_usage(self):
        result = subprocess.run(["bash", str(SCRIPT), "--require-scuttle"], text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("Usage:", result.stderr)
        self.assertNotIn("unbound variable", result.stderr)

    def test_rejects_invalid_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "invalid.apk"
            apk.write_bytes(b"not an archive")
            result = subprocess.run(
                ["bash", str(SCRIPT), str(apk), SDK_RUST, PAYJOIN_RUST, "arm64-v8a"],
                text=True,
                capture_output=True,
                check=False,
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Invalid APK", result.stderr)


class RustPinsInSyncTest(unittest.TestCase):
    def test_containerfile_defaults_match_the_makefile(self):
        # The devcontainer builds Containerfile.tools without the makefile's build args, so its defaults must not drift.
        root = SCRIPT.parents[1]
        pinned = dict(
            line.split("=", 1)
            for line in subprocess.run(["make", "-s", "rust-versions"], cwd=root, env={"PATH": os.environ["PATH"]}, text=True, capture_output=True, check=True).stdout.splitlines()
        )
        containerfile = (root / "Containerfile.tools").read_text()
        for name, version in pinned.items():
            self.assertRegex(containerfile, rf'(?m)^ARG {name}="{re.escape(version)}"$', name)


if __name__ == "__main__":
    unittest.main()
