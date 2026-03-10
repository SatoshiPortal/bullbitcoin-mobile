# Reproducible Build Verification

Scripts for verifying that the published Bull Bitcoin Mobile app matches a build from source.

## Prerequisites

- Docker or Podman
- 8GB+ available RAM
- 50GB+ free disk space
- `curl` and `git` installed
- Local repo checked out at the tag you want to verify (e.g. `git checkout v10.9.8`)

## Usage

```bash
cd reproducibility

# Verify against the GitHub release APK (downloads it automatically)
./verify_build.sh --version 10.9.8

# Verify against a local APK file
./verify_build.sh --version 10.9.8 --apk ./bullbitcoin.apk

# Verify against split APKs extracted from a device (Play Store path)
./verify_build.sh --version 10.9.8 --apk ~/bullbitcoin-splits/

# Clean up the workspace after verification
./verify_build.sh --version 10.9.8 --cleanup
```

## Output

A workspace directory `bullbitcoin_<version>_verification/` is created next to the script containing:

- `RESULTS.md` — verdict, version info, hash, and commit
- `official-decoded/` — apktool decode of the official APK
- `built-decoded/` — apktool decode of the locally built APK
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
