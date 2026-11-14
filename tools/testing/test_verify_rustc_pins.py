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
    "libonion.so": SDK_RUST,
    "librust_lib_bull_sdk.so": SDK_RUST,
    "libbdk_dart_ffi.so": SDK_RUST,
    "libpayjoin_ffi_wrapper.so": PAYJOIN_RUST,
}


class VerifyRustcPinsTest(unittest.TestCase):
    def check_apk(self, *, abis=("arm64-v8a",), changed=None, expected_abis=None):
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
                ["bash", str(SCRIPT), str(apk), SDK_RUST, PAYJOIN_RUST, *(expected_abis or abis)],
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
            changed={"lib/x86_64/libonion.so": b"rustc version 1.100.0\n"}
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
        result = self.check_apk(changed={"lib/arm64-v8a/libonion.so": None})
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
        result = self.check_apk(changed={"lib/arm64-v8a/libonion.so": b"no version"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No rustc version marker", result.stderr)

    def test_rejects_multiple_versions(self):
        result = self.check_apk(
            changed={"lib/arm64-v8a/libonion.so": b"rustc version 1.100.0\nrustc version 1.97.1\n"}
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unexpected rustc markers", result.stderr)

    def test_rejects_unknown_rust_library(self):
        result = self.check_apk(changed={"lib/arm64-v8a/libnew.so": b"rustc version 1.100.0\n"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Untracked Rust library", result.stderr)

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


if __name__ == "__main__":
    unittest.main()
