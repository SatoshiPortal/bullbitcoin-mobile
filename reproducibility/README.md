# Reproducible Build Verification

Scripts for verifying that the published Bull Bitcoin Mobile app matches a build from source.

## How it works

Three components work together:

### `../Containerfile.tools` and `../Containerfile.app` (root)

Two-file build setup driven by `make android release`:

- `Containerfile.tools` installs all toolchains (Rust pinned via `RUST_VERSION`, Flutter via FVM, Android SDK, Gradle).
- `Containerfile.app` copies the repo, runs `pub get` / `build_runner` / `gen-l10n`, and configures Gradle. It does NOT run `flutter build` — that happens via `podman run` against the resulting image so the multi-GB build output is never committed to a layer.

Two environment variables are set at build time to eliminate sources of non-determinism:

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

## Verifying the release signature

[GitHub releases](https://github.com/SatoshiPortal/bullbitcoin-mobile/releases) from 6.12.2 onward ship `HASHSUMS256`, the SHA-256 of the APK, and `HASHSUMS256.asc`, its detached GPG signature. 6.13.0 and 6.13.1 were published without a signature. The signing key is published in this repository at [`keys/i5hi.asc`](../keys/i5hi.asc).

| | Fingerprint |
|---|---|
| Primary key (Vishal Menon, [i5hi](https://github.com/i5hi)) | `BC5A D8A2 6AAC D383 EF63  0D45 5AE8 AC51 D171 F109` |
| Signing subkey | `7247 8AF1 8BD0 F955 3A16  B9F1 9F4E 17C3 203E 0D49` |

The same key is on [keyserver.ubuntu.com](https://keyserver.ubuntu.com/pks/lookup?search=0x72478AF18BD0F9553A16B9F19F4E17C3203E0D49&fingerprint=on&op=index) and at <https://github.com/i5hi.gpg>. Compare the fingerprints there with the ones above before trusting the copy in this repository: whoever can change this file can change this page too.

Download the APK, `HASHSUMS256` and `HASHSUMS256.asc` of a release into the root of a checkout of this repository, then run from that directory:

```bash
gpg --no-default-keyring --keyring ./bull-release.kbx --import keys/i5hi.asc
gpg --no-default-keyring --keyring ./bull-release.kbx --status-fd 1 \
  --verify HASHSUMS256.asc HASHSUMS256 \
  | grep '^\[GNUPG:\] VALIDSIG 72478AF18BD0F9553A16B9F19F4E17C3203E0D49 '
sha256sum --ignore-missing --check HASHSUMS256
```

The dedicated keyring holds only this key, so the `grep` prints a `VALIDSIG` line, and exits with success, only when the signing subkey above made the signature. `gpg` also warns that the key is not certified with a trusted signature: that is expected for a key you have not signed yourself, and is why the fingerprint is checked explicitly. `sha256sum` must then report `OK` for the APK (on macOS, `shasum -a 256 --ignore-missing --check HASHSUMS256`).

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
  `packages/rust_bindings/rust/crates/bitbox/Cargo.toml` pins `bitbox-api-rs` from
  `github.com/ben-kaufman/bitbox-api-rs`, a personal account. Commit-SHA pinning
  makes these resolve to exact bytes today, but a pin doesn't survive the
  commit becoming unreachable (account deleted, repo force-pushed/rewritten).
  Mirroring these forks under the SatoshiPortal org removes that single
  point of failure.
- **Publish build provenance from `build-android.yml`.** The workflow now
  prints the built artifact's sha256 to the job summary, but there's no
  cryptographic attestation tying "this GitHub Actions run, at this commit,
  produced this exact APK" together (e.g. `actions/attest-build-provenance`).
  Adding it needs `id-token: write` / `attestations: write` permissions on a
  job that's currently deliberately minimal-permission (`contents: read`
  only) — a deliberate scope change, not a drop-in fix, so it's flagged here
  for a decision rather than applied silently.
