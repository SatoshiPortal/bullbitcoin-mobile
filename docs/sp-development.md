# SP (Silent Payments) Development

## 1. Toolchains

| Tool | Version | Install |
|---|---|---|
| Rust | stable (rustup) | `rustup toolchain install stable` |
| Flutter | 3.44.2 via fvm (pinned in `.fvmrc`) | `fvm install` in repo root |
| Dart | bundled with Flutter (SDK 3.12.2, per `pubspec.yaml`) | comes with Flutter |
| Java | >= 17 (JDK 21 matches `android.jvmTarget`) | system package manager or [SDKMAN](https://sdkman.io) |
| Android SDK | `compileSdk` 36 | Android Studio SDK Manager |
| Android NDK | `29.0.14206865` (see `android/gradle.properties`) | Android Studio SDK Manager |

The bwk bindings the SP feature calls come from the `bull_sdk` package (see `pubspec.yaml`), not a local crate. Its native Rust libraries (bdk-dart and friends) are compiled by the `rust_builder` plugin during the Android/iOS build, which is why the Rust toolchain and Android targets above are required.

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

## 3. `make sp-*` Targets

| Target | Description |
|---|---|
| `sp-analyze` | Runs `build_runner`, then the strict `analyze` target (`--fatal-warnings --fatal-infos`) across the whole project |
| `sp-audit` | Runs the SP invariant audit (`scripts/audit-sp-invariant.sh`) |
| `sp-verify-all` | Runs `sp-analyze`, then `sp-audit`, then the SP Flutter tests |

`make sp-verify-all` is the local verification entry point. CI does not run it as one target: the `analyze_and_test.yml` workflow runs `make sp-audit`, `make analyze`, `make unit-test`, and the integration tests on every PR (no path filter), so the audit sees changes anywhere in the repo, not just under `lib/features/sp/`.

## 4. Tests and the No-Autoscan Invariant

The SP suite is pure Dart. `make sp-verify-all` runs `flutter analyze`, the invariant audit, and the SP Flutter tests under `test/features/sp/` plus the related settings and wallet tests and `test/integration/sp_global_wiring_test.dart`.

The invariant audit (`scripts/audit-sp-invariant.sh`) enforces that SP scanning is user-triggered only: `SpCubit.scan()` may be called only from SP UI handlers, `scanOnce`/`ScanSpWalletUsecase` stay confined to their few allowed files, and no scan is wired from a lifecycle or background hook in the SP or sync layer.

## 5. Reproducible Build

The reproducible APK/AAB build runs in a container via `make android`; see `reproducibility/README.md`. It is a separate lane. `make sp-verify-all` never invokes it, and developers do not need it for day-to-day SP work.
