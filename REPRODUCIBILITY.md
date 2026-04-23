# Reproducible Build Verification

Scripts for verifying that the published Bull Bitcoin Mobile app matches a build from source.

## How it works

Three components work together:

### `Dockerfile`

Sets up the build toolchain (Rust, Flutter via FVM, Android SDK, Gradle) and also installs `apktool` and `bundletool` — used by `scripts/verify_build.sh` to decode APKs and to generate splits from an AAB. The image contains only the toolchain; the repo source is never copied in, so no secret or local state can end up in image layers.

### `scripts/build.sh`

Runs inside the `bull-mobile` container with the repo bind-mounted at `/app`. It does `pub get` / `build_runner` / `gen-l10n`, configures Gradle, then runs `flutter build appbundle`. One environment variable is set to eliminate sources of non-determinism:

- `SOURCE_DATE_EPOCH` — set to the timestamp of the latest git commit (`git log -1 --format=%ct`). OpenSSL embeds a wall-clock build timestamp in compiled binaries by default; setting this variable makes it use a fixed value instead, so any `.so` that links against OpenSSL (`libark_wallet.so`, `libboltz.so`, `libtor.so`) is identical across builds.

`bundletool` then extracts a universal APK from the signed AAB. When release signing credentials are provided via env vars (`KEYSTORE_FILE`, `KEYSTORE_PASS`, `KEY_ALIAS`, `KEY_PASS`), the AAB is signed with `jarsigner` and the APK with the release key; otherwise the AAB is produced unsigned and the APK is signed with the committed debug keystore — which is fine for reproducibility verification since `META-INF` is stripped from the diff anyway.

### `scripts/verify_build.sh`

Orchestrates the full verification:

1. Builds the `bull-mobile` base image (provides apktool, bundletool, and the build toolchain)
2. Optionally downloads the official APK from the GitHub release, or uses a locally provided APK or split APK directory
3. Builds the app from the current repo checkout by running `bull-mobile` with the repo bind-mounted and invoking `scripts/build.sh`
4. Reads the built artifact from the bind-mounted repo root (`app-release.apk` / `app-release.aab`)
5. Decodes both APKs with apktool (inside `bull-mobile`)
6. Diffs the decoded output excluding `META-INF` (signatures are not part of reproducibility)
7. Writes a `RESULTS.md` verdict to the workspace directory

For two builds to be byte-identical, both must use the exact same git commit. `SOURCE_DATE_EPOCH` is derived from `git log -1 --format=%ct`, so if two builds are from different commits they will embed different timestamps and the `.so` files will differ.

---

## Prerequisites

- Docker or Podman
- 8GB+ available RAM
- 100GB+ free disk space
- `curl` and `git` installed

## Usage

The makefile wraps the verification script:

```bash
# Verify against the GitHub release APK (downloads it automatically)
# Repo must be checked out at the matching tag (e.g. git checkout vXYZ)
make verify VERSION=XYZ

# Verify a locally provided APK against a fresh build from the current checkout
make verify APK=./bullbitcoin.apk

# Same, with an explicit version (used in the workspace directory name)
make verify VERSION=XYZ APK=./bullbitcoin.apk

# Verify against split APKs extracted from a device (Play Store path)
make verify APK=~/bullbitcoin-splits/
```

For flags not exposed by `make verify` (e.g. `--cleanup`, `--yes`), call the script directly:

```bash
./scripts/verify_build.sh --apk ./bullbitcoin.apk --cleanup
```

To just produce a build artifact without verification, use `make build` (see the makefile for `MODE` and release-signing env vars).

## Output

A workspace directory `bullbitcoin_<version>_verification/` is created at the repo root containing:

- `RESULTS.md` — verdict, version info, hash, and commit
- `official-decoded/` — apktool decode of the reference APK
- `built-decoded/` — apktool decode of the freshly built APK
- `diff.txt` / `diff_<split>.txt` — differences found, if any (excluding META-INF)

## Extracting split APKs from a device (Play Store path)

```bash
adb shell pm path com.bullbitcoin.mobile
# outputs something like: package:/data/app/com.bullbitcoin.mobile-.../base.apk
adb pull /data/app/com.bullbitcoin.mobile-.../base.apk ~/bullbitcoin-splits/
adb pull /data/app/com.bullbitcoin.mobile-.../split_config.arm64_v8a.apk ~/bullbitcoin-splits/
# pull any other split_config.*.apk files listed
```

Then pass `APK=~/bullbitcoin-splits/` to `make verify`.
