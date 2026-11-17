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
    def check_apk(self, *, abis=("arm64-v8a",), changed=None, expected_abis=None, require_bark=False):
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
            result = subprocess.run(
                ["bash", str(SCRIPT), *(["--require-bark"] if require_bark else []), str(apk), SDK_RUST, PAYJOIN_RUST, *(expected_abis or abis)],
                text=True,
                capture_output=True,
                check=False,
            )
        return result

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

    def test_accepts_exact_bark_compiler_with_legacy_and_required_cli(self):
        for required in (False, True):
            with self.subTest(required=required):
                result = self.check_apk(
                    changed={"lib/arm64-v8a/libbark_ffi_dart.so": b"rustc version 1.90.0\nrustc version 1.90.0\n"},
                    require_bark=required,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("libbark_ffi_dart.so: rustc 1.90.0", result.stdout)

    def test_required_bark_is_checked_in_every_expected_abi(self):
        abis = ("arm64-v8a", "x86_64")
        for missing in (None, "arm64-v8a", "x86_64"):
            with self.subTest(missing=missing):
                result = self.check_apk(
                    abis=abis,
                    changed={f"lib/{abi}/libbark_ffi_dart.so": b"rustc version 1.90.0\n" for abi in abis if abi != missing},
                    require_bark=True,
                )
                if missing is None:
                    self.assertEqual(result.returncode, 0, result.stderr)
                else:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(f"Missing tracked Rust library: {missing}/libbark_ffi_dart.so", result.stderr)

    def test_rejects_required_bark_absent_in_single_abi(self):
        result = self.check_apk(require_bark=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing tracked Rust library: arm64-v8a/libbark_ffi_dart.so", result.stderr)

    def test_rejects_wrong_missing_or_mixed_bark_markers(self):
        for markers, diagnostic in (
            (b"rustc version 1.100.0\n", "Unexpected rustc markers"),
            (b"no version", "No rustc version marker"),
            (b"rustc version 1.90.0\nrustc version 1.100.0\n", "Unexpected rustc markers"),
        ):
            with self.subTest(markers=markers):
                result = self.check_apk(changed={"lib/arm64-v8a/libbark_ffi_dart.so": markers})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stderr)

    def test_rejects_extra_abi_bark_without_marker(self):
        result = self.check_apk(changed={"lib/x86_64/libbark_ffi_dart.so": b"no version"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Tracked Rust library in unexpected ABI", result.stderr)

    def test_rejects_unknown_library_with_bark_compiler(self):
        result = self.check_apk(changed={"lib/arm64-v8a/libother.so": b"rustc version 1.90.0\n"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Untracked Rust library", result.stderr)

    def test_bare_required_bark_flag_reports_usage(self):
        result = subprocess.run(["bash", str(SCRIPT), "--require-bark"], text=True, capture_output=True, check=False)
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
