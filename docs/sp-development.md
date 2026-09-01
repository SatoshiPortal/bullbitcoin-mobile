# SP (Silent Payments) Development

## 1. Toolchains

| Tool | Version | Install |
|---|---|---|
| Rust | stable (rustup) | `rustup toolchain install stable` |
| Flutter | 3.44.9 via fvm (pinned in `.fvmrc`) | `fvm install` in repo root |
| Dart | bundled with Flutter (SDK 3.12.2, per `pubspec.yaml`) | comes with Flutter |
| Java | >= 17 (JDK 21 matches `android.jvmTarget`) | system package manager or [SDKMAN](https://sdkman.io) |
| Android SDK | `compileSdk` 36 | Android Studio SDK Manager |
| Android NDK | `29.0.14206865` (see `android/gradle.properties`) | Android Studio SDK Manager |

The bwk bindings the SP feature calls come from the `bull_sdk` package (see `pubspec.yaml`), not a local crate. Its native Rust library (`rust_lib_bull_sdk`) is compiled by the `rust_builder` plugin during the Android/iOS build, which is why the Rust toolchain and Android targets above are required.

`bull_sdk` is pinned in `dependency_overrides` to a fork (`github.com/pythcoiner/bull_sdk`) that carries SP support not yet upstream: a restartable electrum listener and `Account::broadcast` for eager spend marking. Drop that override once those changes land in the upstream bull_sdk.

Run `make fvm-check` to install the pinned Flutter, then `make deps` to fetch dependencies before starting.

## 2. Environment Variables

| Variable | Required? | Default / fallback | Used by |
|---|---|---|---|
| `ANDROID_HOME` | Yes | none, must be set and point to a real dir | Android Gradle build, NDK lookup |
| `ANDROID_NDK_HOME` | No | derived from `$ANDROID_HOME/ndk/<latest>` | `rust_builder` Rust cross-compile to Android |
| `JAVA_HOME` | No | derived from `java` on PATH | Gradle (only when not on PATH) |
| `PATH` | Yes, must contain `fvm` (or `flutter`) and `~/.cargo/bin` | system-default + shell rc | every Flutter/cargo command |

**`ANDROID_HOME`** - if unset or pointing to a non-existent directory, Gradle falls back to scanning common locations and usually fails with a confusing `SDK location not found` error during the Android build step. Set it to the directory containing `platforms/`, `platform-tools/`, and `ndk/`.

**`ANDROID_NDK_HOME`** - if unset, the Rust build derives the NDK path from `$ANDROID_HOME/ndk/<latest installed version>`. If no NDK is installed, the Rust Android cross-compile step fails with a path resolution error. Install the NDK version listed in `android/gradle.properties` via Android Studio's SDK Manager.

**`JAVA_HOME`** - Gradle can usually locate Java from PATH, but when multiple JDKs are installed the wrong one may be picked. Setting `JAVA_HOME` explicitly avoids version mismatches. Leave unset if only one JDK is installed and it reports the expected major version.

**`PATH`** - must include the `fvm` binary (or plain `flutter`) and `~/.cargo/bin`. Missing entries surface immediately as `command not found` for `fvm`, `flutter`, or `cargo`.

## 3. Verifying a Change

There is no SP-specific make target. `make checks` is the local entry point: it runs the strict `analyze` (`--fatal-warnings --fatal-infos`), the formatting and `dart fix` checks, and `make unit-test`, which is the same set CI runs in the `analyze_and_test.yml` workflow on every PR.

## 4. Tests and the Scan Policy

The SP suite needs no native libraries. `make unit-test` picks up the SP tests under `test/features/sp/` along with the rest of the project.

Scanning resumes on its own during a sync tick, but only through `SyncSpWalletUsecase`, and only when `spScanTrigger` says so: a wallet with no cursor yet, or one more than about a month behind the tip, stays on the manual path until the user acts.

That confinement is enforced by the type system rather than by a grep. `scanOnce` lives alone on `SpScanPort`, and the locator hands that port to `ScanSpWalletUsecase` and nothing else, so no other class can reach the Rust scan without a visible change to the composition root. `sp_locator_scan_policy_test.dart` covers the behaviour on top of that: it boots the real locator graph with only the outbound ports faked and counts every `scanOnce` that reaches the boundary.

## 5. Reproducible Build

The reproducible APK/AAB build runs in a container via `make android`; see `reproducibility/README.md`. It is a separate lane. `make checks` never invokes it, and developers do not need it for day-to-day SP work.
