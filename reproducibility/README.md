# Reproducible Build Verification

Scripts for verifying that the published Bull Bitcoin Mobile app matches a build from source.

## How it works

Three components work together:

### `../Containerfile.tools` and `../Containerfile.app` (root)

Two-file build setup driven by `make android release`:

- `Containerfile.tools` installs all toolchains (Rust pinned via `RUST_VERSION`, Flutter via FVM, Android SDK, Gradle).
- `Containerfile.app` copies the repo, runs `pub get` / `build_runner` / `gen-l10n`, and configures Gradle. It does NOT run `flutter build` — that happens via `podman run` against the resulting image so the multi-GB build output is never committed to a layer.

Two environment variables are set at build time to eliminate sources of non-determinism:

- `SOURCE_DATE_EPOCH` — set to the timestamp of the latest git commit (`git log -1 --format=%ct`). OpenSSL embeds a wall-clock build timestamp in compiled binaries by default; setting this variable makes it use a fixed value instead, so any `.so` that links against OpenSSL (e.g. `libtor.so` and `libonion.so`) is identical across builds. The exact set of shipped Rust `.so` files is confirmed by a real build, not by this doc; the toolchain-pinned subset that `make verify-rustc-pins` checks is the `TRACKED_RUST_LIBS` list in the [`makefile`](../makefile) — keep that list authoritative and this sentence illustrative.
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

## Known gaps that need infra/org access to close

These came out of a full reproducibility audit (2026-07) but require access
this repo's tooling doesn't have (a container registry, admin rights on the
SatoshiPortal GitHub org) — tracked here rather than silently dropped:

- **Archive the exact `bull-tools`/`bull-app` image per release.** Everything
  in `Containerfile.tools` is version-pinned, but several inputs are still
  fetched live at image-build time with no content pin: apt packages
  (including the JDK that runs javac/Gradle) resolve to whatever Debian
  `trixie` currently ships, the FVM and rustup install scripts are fetched
  unpinned from `fvm.app`/`sh.rustup.rs`, and the Flutter SDK/engine
  artifacts come from a mutable git tag and Google's CDN respectively.
  Pinned *versions* make a same-week rebuild match by coincidence, not by
  guarantee — an apt/JDK point release six months out is a plausible way for
  a byte-identical rebuild to silently stop matching. Push the built image to
  a registry (or `podman save` a tarball) per release and record its digest
  in the release notes; verifiers can then pull the frozen toolchain instead
  of re-resolving it. **Caveat — never archive an image built with beta signing
  secrets present.** `.dockerignore` deliberately re-includes
  `android/app/beta-upload.keystore` and does not exclude
  `android/key-beta.properties` (which holds the store/key passwords), so a
  *beta* build's `bull-app` layers contain live signing material — safe only on
  an ephemeral runner. Only images built for `release`/verification (where
  `build-android.yml` materializes beta secrets solely for `mode == 'beta'`, so
  they are absent otherwise) may be pushed or saved. Confirm the keystore and
  properties are not in the image before archiving.
- **Mirror personal-account git dependencies into the SatoshiPortal org.**
  `bull_sdk`'s `Cargo.toml` pins `bitbox-api-rs` from
  `github.com/ben-kaufman/bitbox-api-rs`, a personal account. Commit-SHA pinning
  makes these resolve to exact bytes today, but a pin doesn't survive the
  commit becoming unreachable (account deleted, repo force-pushed/rewritten).
  Mirroring these forks under the SatoshiPortal org removes that single
  point of failure. The same applies with lower urgency to `bull_sdk`'s three
  `branch = "migrate-to-bull-sdk"` cargo dependencies (already SatoshiPortal
  repos) — convert to `rev =` once that branch is merged/retired upstream so
  a future branch deletion can't break the pin (already fixed in the current
  `migrate-to-bull-sdk` checkout; needs review/merge in `bull_sdk`).
- **Publish build provenance from `build-android.yml`.** The workflow now
  prints the built artifact's sha256 to the job summary, but there's no
  cryptographic attestation tying "this GitHub Actions run, at this commit,
  produced this exact APK" together (e.g. `actions/attest-build-provenance`).
  Adding it needs `id-token: write` / `attestations: write` permissions on a
  job that's currently deliberately minimal-permission (`contents: read`
  only) — a deliberate scope change, not a drop-in fix, so it's flagged here
  for a decision rather than applied silently.
