# Reproducible Build Verification

Scripts for verifying that the published Bull Bitcoin Mobile app matches a build from source.

## How it works

Three components work together:

### `../Dockerfile` (root)

Builds the app from source in a clean, hermetic environment. It installs all toolchains (Rust, Flutter via FVM, Android SDK, Gradle), copies the repo into the image, and runs `flutter build`. Two environment variables are set at build time to eliminate sources of non-determinism:

- `SOURCE_DATE_EPOCH` — set to the timestamp of the latest git commit (`git log -1 --format=%ct`). OpenSSL embeds a wall-clock build timestamp in compiled binaries by default; setting this variable makes it use a fixed value instead, so any `.so` that links against OpenSSL (`libark_wallet.so`, `libboltz.so`, `libtor.so`) is identical across builds.
- `CARGO_ENCODED_RUSTFLAGS` — three `--remap-path-prefix` flags that rewrite absolute paths baked into Rust binaries at compile time (home directory, `.cargo`, `.rustup`) to fixed strings (`/cargo`, `/rustup`, `/build`). cargokit reads `CARGO_ENCODED_RUSTFLAGS` rather than `RUSTFLAGS`; flags are separated by the ASCII unit separator `\x1f` (octal `\037`).

### `Dockerfile` (this directory)

A small verification tools image containing apktool, bundletool, and Java. It is used only for decoding APKs — it never builds the app. `verify_build.sh` builds this image automatically and runs apktool/bundletool inside it so no local Java installation is required.

### `verify_build.sh`

Orchestrates the full verification:

1. Builds the verification tools image from `Dockerfile`
2. Optionally downloads the official APK from the GitHub release, or uses a locally provided APK or split APK directory
3. Builds the app from the current repo checkout using the root `Dockerfile`
4. Extracts the built artifact from the Docker image
5. Decodes both APKs with apktool (inside the tools container)
6. Diffs the decoded output excluding `META-INF` (signatures are not part of reproducibility)
7. Writes a `RESULTS.md` verdict to the workspace directory

For Docker-to-Docker comparisons to be reproducible, both builds must use the exact same git commit. `SOURCE_DATE_EPOCH` is derived from `git log -1 --format=%ct`, so if two builds are from different commits they will embed different timestamps and the `.so` files will differ.

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
```

## Output

A workspace directory `bullbitcoin_<version>_verification/` is created next to the script containing:

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

Then pass `--apk ~/bullbitcoin-splits/` to the script.
