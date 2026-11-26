# SP (Silent Payments) Development

## 1. Toolchains

| Tool | Version | Install |
|---|---|---|
| Rust | 1.100.0 for SatoshiPortal hooks; 1.85.1 for official Payjoin | `rustup toolchain install 1.100.0 1.85.1 --profile minimal` |
| Flutter | 3.50.0 via fvm (pinned in `.fvmrc`) | `fvm install` in repo root |
| Dart | bundled with Flutter (SDK 3.14.0, per `pubspec.yaml`) | comes with Flutter |
| Java | JDK 21 (matches `android.jvmTarget`) | system package manager or [SDKMAN](https://sdkman.io) |
| Android SDK | `compileSdk` 37 (SDK platform 37.0) | Android Studio SDK Manager |
| Android NDK | `29.0.14206865` (see `android/gradle.properties`) | Android Studio SDK Manager |

The bwk bindings the SP feature calls come from the `rust_bindings` workspace package (its `rust/crates/bwk` crate). Its native Rust library (`rust_lib_bull_sdk`) is compiled by Native Assets hooks during the Android/iOS build, which is why the pinned Rust toolchains and platform targets are required. The accepted wrappers use Flutter Rust Bridge 2.13 and hooks 2; BDK uses UniFFI through its own Native Assets hook.

`rust_bindings` builds from its own locked Cargo graph (`packages/rust_bindings/rust/Cargo.lock`); `make deps` enforces the shared Dart lockfile. Official hosted Payjoin selects Rust 1.85.1 explicitly; `RUSTUP_TOOLCHAIN=1.100.0` does not override that explicit selection. The makefile exports the SatoshiPortal compiler pin and disables implicit Rust toolchain installation.

Run `make fvm-check` to install the pinned Flutter, then `make deps` to fetch dependencies before starting.

## 2. Environment Variables

| Variable | Required? | Default / fallback | Used by |
|---|---|---|---|
| `ANDROID_HOME` | Yes | none, must be set and point to a real dir | Android Gradle build, NDK lookup |
| `ANDROID_NDK_HOME` | No | derived from `$ANDROID_HOME/ndk/<latest>` | Native Assets Rust cross-compile to Android |
| `JAVA_HOME` | No | derived from `java` on PATH | Gradle (only when not on PATH) |
| `PATH` | Yes, must contain `fvm` and `~/.cargo/bin` | system-default + shell rc | every Flutter/cargo command |

**`ANDROID_HOME`** - if unset or pointing to a non-existent directory, Gradle falls back to scanning common locations and usually fails with a confusing `SDK location not found` error during the Android build step. Set it to the directory containing `platforms/`, `platform-tools/`, and `ndk/`.

**`ANDROID_NDK_HOME`** - if unset, the Rust build derives the NDK path from `$ANDROID_HOME/ndk/<latest installed version>`. If no NDK is installed, the Rust Android cross-compile step fails with a path resolution error. Install the NDK version listed in `android/gradle.properties` via Android Studio's SDK Manager.

**`JAVA_HOME`** - Gradle can usually locate Java from PATH, but when multiple JDKs are installed the wrong one may be picked. Setting `JAVA_HOME` explicitly avoids version mismatches. Leave unset if only one JDK is installed and it reports the expected major version.

**`PATH`** - must include the `fvm` binary and `~/.cargo/bin`. Missing entries surface immediately as `command not found` for `fvm` or `cargo`.

## 3. Verifying a Change

There is no SP-specific make target. `make checks` is the local entry point: it runs the strict `analyze` (`--fatal-warnings --fatal-infos`), the formatting and `dart fix` checks, and `make unit-test`, which is the same set CI runs in the `analyze_and_test.yml` workflow on every PR.

## 4. Tests and the Scan Policy

`make unit-test` picks up the Silent Payments suite under `features/silent/test/` along with the rest of the workspace. To run only this suite, run `fvm flutter test` from `features/silent`.

Automatic scanning runs only in the foreground through `SyncSpWalletUsecase`. It can resume a manual scan that previously started and was not paused with Stop. A failed automatic scan can be retried in the same session, but still follows `SpScanPolicy`: a wallet with no cursor or one more than about a month behind the tip needs a manual start. Stop blocks automatic scans even after reopening the account, until the user starts a scan or clears the scan state. WorkManager does not start Silent Payments scans.

Changing backends reconnects the existing account in place. Service Status only checks the configured Blindbit tip for an admitted Silent Payments wallet; the setup and settings checks also sample the scan data endpoints. Existing configurations without a minimum scan amount retain 600 sats. New configurations default to 1,000 sats, and lowering the amount does not automatically rescan earlier blocks.

That confinement is enforced by the type system rather than by a grep. `scanOnce` lives alone on `SpScanPort`, and the feature graph hands that port to `ScanSpWalletUsecase` and nothing else, so no other class can reach the Rust scan without a visible change to the composition root. `silent_graph_scan_policy_test.dart` covers the behaviour on top of that: it boots the real feature graph with only the outbound ports faked and counts every `scanOnce` that reaches the boundary.

## 5. Reproducible Build

The reproducible APK/AAB build runs in a container via `make android`; see `reproducibility/README.md`. It is a separate lane. `make checks` never invokes it, and developers do not need it for day-to-day SP work.
