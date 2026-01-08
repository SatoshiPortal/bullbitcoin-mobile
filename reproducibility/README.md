# Reproducible Build Verification for Bull Bitcoin Mobile

This directory contains tools and documentation for verifying that Bull Bitcoin Mobile builds are reproducible - meaning anyone can independently build the app from source code and verify they get the exact same binary.

### Prerequisites

- **Docker or Podman**
- **Recommended 8GB RAM**
- **~50GB free disk space**

### Usage

```bash
# Verify from GitHub release (universal APK)
./verify_build --version <version>

# Verify from device (split APKs)
./verify_build --version <version> --apk /path/to/apk/directory/

# Clean up workspace after verification
./verify_build --version <version> --cleanup

# Preserve built APKs for analysis
./verify_build --version <version> --preserve
```

### What the Script Does

1. Sets up build environment: Creates a containerized Ubuntu environment with Flutter, Android SDK, and Rust
2. Clones source code: Checks out the exact release tag from GitHub
3. Builds from source: Compiles the app using the same process as the official release
4. Extracts APKs: Uses bundletool to extract APKs from the built AAB
5. Compares binaries: Decodes and compares the built APK against the official release
6. Reports results: Shows whether the build is reproducible or not

### Understanding Results

- **Reproducible**: Built APK matches official release exactly (excluding signatures)
- **Differences found**: Built APK differs from official release - investigate diff files in workspace

Diff files are saved in `bullbitcoin_<version>_verification/results/` for detailed analysis.

## Notes

- This script losely follows [WalletScrutiny's Script Standards](https://gitlab.com/walletScrutiny/walletScrutinyCom/-/blob/master/docs/script_verifications.md) for reproducible verification scripts.
- The binary verification system using nostr built by WalletScrutiny produces `kind: 30301` verification events. [This verification event](https://nostr.at/nevent1qqsvkpulglcjqrka866rtnw7ehgh9c778dzlserwul20pgwsrt34aegzyq0eu4ru9ucegf3rhzk36pm3x2pwseq0mr85wn5l08cc4n527gtw6z9rvwa) was a result of running [this script](https://nostr.at/nevent1qqszpl97xn5udw8vmxc8wdh2673lu53dmeyw90fnegfqn9f44g5l04qzyq0eu4ru9ucegf3rhzk36pm3x2pwseq0mr85wn5l08cc4n527gtw65sudg7). Our script is an iteration of that, with some fixes.


## References

- WalletScrutiny Verification NIP: [verifications.md](https://gitlab.com/walletScrutiny/walletScrutinyCom/-/blob/master/docs/verifications.md)
- WalletScrutiny Script Standards: [script_verifications.md](https://gitlab.com/walletScrutiny/walletScrutinyCom/-/blob/master/docs/script_verifications.md)
