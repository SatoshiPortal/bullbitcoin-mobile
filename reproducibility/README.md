# Reproducible Build Verification

Scripts for verifying that the published Bull Bitcoin Mobile app matches a build from source.

## How it works

Three components work together:

### `../Containerfile.tools` and `../Containerfile.app` (root)

Two-file build setup driven by `make android release`:

- `Containerfile.tools` installs all toolchains (Rust pinned via `RUST_VERSION`, Flutter via FVM, Android SDK, Gradle).
- `Containerfile.app` copies the repo, runs `pub get` / `build_runner` / `gen-l10n`, and configures Gradle. It does NOT run `flutter build` — that happens via `podman run` against the resulting image so the multi-GB build output is never committed to a layer.

The container uses fixed paths (`/app`, `/home/bull`, `/opt/android-sdk`). Keep these paths when reproducing an APK: Flutter native hooks filter some environment variables, and native libraries can embed paths even when Rust remapping is requested. Build metadata is computed on the host and passed to the container, so Git worktrees are supported without copying host-only `.git` pointers.

Two environment variables are set at build time to reduce sources of non-determinism:

- `SOURCE_DATE_EPOCH` — set to the timestamp of the latest git commit (`git log -1 --format=%ct`). OpenSSL embeds a wall-clock build timestamp in compiled binaries by default; setting this variable makes it use a fixed value instead, so any `.so` that links against OpenSSL (e.g. `libonion.so`) is identical across builds. The exact set of shipped Rust `.so` files is confirmed by a real build, not by this doc; the toolchain-pinned subset that `make verify-rustc-pins` checks is the `TRACKED_RUST_LIBS` list in the [`makefile`](../makefile) — keep that list authoritative and this sentence illustrative.
- `CARGO_ENCODED_RUSTFLAGS` — three `--remap-path-prefix` flags that rewrite absolute paths baked into Rust binaries at compile time (home directory, `.cargo`, `.rustup`) to fixed strings (`/cargo`, `/rustup`, `/build`). cargokit reads `CARGO_ENCODED_RUSTFLAGS` rather than `RUSTFLAGS`; flags are separated by the ASCII unit separator `\x1f` (octal `\037`).

After extracting the APK, `make android` (for `FORMAT=apk`) also runs `make verify-rustc-pins`, which greps the embedded `rustc version` string out of every shipped Rust `.so` and compares it against the pinned toolchains running live inside `bull-app`. This exists because `Containerfile.tools`'s `RUSTUP_TOOLCHAIN` pin only covers cargo/rustc invocations that read that env var — cargokit and `bdk_dart`'s native-assets build hook both invoke `rustup run <toolchain>` directly, which bypasses it. See the `rustup` shim installed near the end of `Containerfile.tools` for the actual fix (it rewrites cargokit's hard-coded `stable` argument to the pinned `RUST_VERSION`; `rustup toolchain link stable` is *not* usable because rustup ≥1.28 rejects the reserved channel name); this check exists to catch a regression of that fix, not to work around its absence.

### `Dockerfile` (this directory)

A small verification tools image containing apktool, bundletool, and Java. It is used only for decoding APKs — it never builds the app. `verify_build.sh` builds this image automatically and runs apktool/bundletool inside it so no local Java installation is required.

### `verify_build.sh`

Orchestrates the full verification:

1. Checks that the working tree has no uncommitted changes to tracked files (a dirty tree would build modified sources while still attesting the clean commit hash) — override with `--allow-dirty` if you really mean to
2. Builds the verification tools image from `Dockerfile`
3. Optionally downloads the official APK from the GitHub release, or uses a locally provided APK or split APK directory
4. Builds the app from the current repo checkout via `make android release` (which uses the root `Containerfile.tools` + `Containerfile.app`)
5. Picks up the extracted APK from the repo root (`./BULL-release.apk`)
6. Compares every zip entry's raw content hash between the two APKs via `compare_apk_entries.sh` (inside the tools container) — this is the actual verdict. The only exclusion is the legacy JAR signature files (`MANIFEST.MF`, `*.RSA`, `*.SF`, `*.EC`, `*.DSA`), which exist only because the official APK is signed and the from-source build deliberately is not; everything else, including `META-INF/services/*` ServiceLoader registrations and other non-signature `META-INF` content, is compared
7. Also decodes both APKs with apktool (inside the tools container) and diffs the decoded output with the same signature-file exclusion — this is a diagnostic aid to help explain *what* differs, not the verdict, since baksmali/aapt2 decoding can normalize away real byte-level differences
8. Writes a `RESULTS.md` verdict to the workspace directory

For build-to-build comparisons to be reproducible, both builds must use the exact same git commit. `SOURCE_DATE_EPOCH` is derived from `git log -1 --format=%ct`, so if two builds are from different commits they will embed different timestamps and the `.so` files will differ.

---

## Prerequisites

- Docker or Podman
- 8GB+ available RAM
- 50GB+ free disk space
- `curl` and `git` installed

## Usage

```bash
cd reproducibility

# Verify against the GitHub release APK (downloads it automatically)
# Repo must be checked out at the matching tag (e.g. git checkout v10.9.8)
./verify_build.sh --version 10.9.8

# Verify a locally provided APK against a fresh build from the current checkout
./verify_build.sh --apk ./bullbitcoin.apk

# Same, with an explicit version (used in the workspace directory name)
./verify_build.sh --version 10.9.8 --apk ./bullbitcoin.apk

# Verify against split APKs extracted from a device (Play Store path)
./verify_build.sh --apk ~/bullbitcoin-splits/

# Clean up the workspace after verification
./verify_build.sh --apk ./bullbitcoin.apk --cleanup

# Proceed despite uncommitted local changes (not recommended — the build
# would embed changes that RESULTS.md won't reflect)
./verify_build.sh --apk ./bullbitcoin.apk --allow-dirty
```

## Output

A workspace directory `bullbitcoin_<version>_verification/` is created next to the script containing:

- `RESULTS.md` — verdict, version info, hash, and commit
- `raw_entry_diff.txt` / `raw_entry_diff_<split>.txt` — the authoritative per-entry content-hash differences, if any
- `official-decoded/` — apktool decode of the reference APK (diagnostic only)
- `built-decoded/` — apktool decode of the freshly built APK (diagnostic only)
- `diff.txt` / `diff_<split>.txt` — decoded differences, if any, excluding legacy JAR signature files (diagnostic only, not the verdict)

## Extracting split APKs from a device (Play Store path)

```bash
adb shell pm path com.bullbitcoin.mobile
# outputs something like: package:/data/app/com.bullbitcoin.mobile-.../base.apk
adb pull /data/app/com.bullbitcoin.mobile-.../base.apk ~/bullbitcoin-splits/
adb pull /data/app/com.bullbitcoin.mobile-.../split_config.arm64_v8a.apk ~/bullbitcoin-splits/
# pull any other split_config.*.apk files listed
```

Then pass `--apk ~/bullbitcoin-splits/` to the script.

## Keeping inputs stable over time

Rust release manifests are checked against reviewed SHA-256 values before installation; they pin the compiler archive hashes as well as version numbers. The Flutter Git revision is checked explicitly after FVM installation, so a moved version tag is refused. APT uses the dated Debian snapshot declared in `Containerfile.tools`, freezing the JDK and transitive system packages. Android platform-tools and platform API revisions use versioned archives and reviewed SHA-256 values in `install-android-pins.sh`; unknown API levels fail closed. NDK, CMake and build-tools archives are also checked against reviewed SHA-256 values.

Gradle compile/runtime dependency graphs use strict lockfiles under `android/gradle/dependency-locks/`. Maven artifacts and metadata are checked against `android/gradle/verification-metadata.xml`; an unexpected version or checksum fails the build. During an intentional dependency update, regenerate them inside the canonical build container with `./gradlew --write-locks --write-verification-metadata sha256 resolveApkDependencies` from `/app/android`, also run the intended assemble task with `--write-verification-metadata sha256` to include detached build-tool dependencies (such as AAPT2), copy the files back, and review every version/checksum change. Generated checksums record the downloaded bytes; independently check new dependencies before accepting them.

Run `make reproducibility-scripts-test` for the fast script regression suite. Run `bash reproducibility/test.sh release` for two complete builds with `--no-cache` on both image stages. The Build Android workflow offers the same test through `verify_reproducibility` (release/APK only). Every shipped ABI must contain all four tracked Rust libraries with the expected compiler versions. Duplicate ZIP member names are rejected by the APK comparator.

Toolchain updates are deliberate: update the snapshot or archive pins, regenerate dependency locks/checksums as needed, and compare two clean builds from the same commit. Pinning does not guarantee that a remote archive or Git commit remains available forever. Archive or mirror the reviewed inputs and the unsigned release toolchain per release; never publish images containing beta signing secrets. Flutter engine archive hashes and authenticated build provenance remain follow-up work.

## Release archival and remaining availability work

Save or publish the exact unsigned release toolchain image and its digest alongside each release. Pins detect changed content; mirrors or archives are needed when a provider removes the original content. Confirm that neither `android/app/beta-upload.keystore` nor `android/key-beta.properties` is present before archiving an app image: beta images can contain signing secrets in their layers. The tools image contains no app signing material.

Mirror personal-account Git dependencies under the organization while preserving the pinned commits, including the SDK's transitive forks. SDK manifest locking is maintained in the separate `bull_sdk` change; this PR does not change the app's SDK revision. Publish authenticated build provenance when the organization enables the required attestation permissions.
