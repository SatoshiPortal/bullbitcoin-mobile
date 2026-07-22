# Coldcard Firmware Update

**Issue:** SatoshiPortal/bullbitcoin-mobile#1260 (CKCC support, firmware-update slice)
**Status:** Implemented on the feature branch; this records the final architecture and verification contract
**Research checked:** 2026-07-13 against coldcard.com, Coldcard/firmware, Keybase, and the Ubuntu keyserver

## Scope

The app supports Coldcard Q and Mk4 firmware updates:

> Settings → Bitcoin settings → Coldcard firmware update → select Q or Mk4 → discover the latest release → download and verify → export the verified `.dfu` with its original filename.

USB discovery and flashing, automated upgrades, Mk3, Tor routing, changelogs, and publishing the package to pub.dev are outside this slice.

## Ownership and boundaries

`packages/coldcard_firmware` is a pure-Dart domain package with no Flutter dependency. It owns:

- the public `ColdcardModel` and `FirmwareRelease` domain types;
- discovery from the Coldcard model pages, with signed-manifest fallback;
- bounded download and progress reporting;
- PGP manifest verification and independent SHA-256 verification;
- opaque `DownloadedFirmware` and `VerifiedFirmware` values with private constructors;
- typed `ColdcardFirmwareException` failures.

The public production client remains the three-call API:

```dart
final release = await client.fetchLatest(model);
final downloaded = await client.download(release, onProgress: onProgress);
final verified = await client.verify(downloaded);
```

Production endpoints and the trust anchor are not configurable through the exported API. Package-owned offline tests use an unexported test factory. `dart_pg` is pinned to `2.0.0`: `2.1.0` requires Pointy Castle 4.x, which conflicts with `ledger_bitcoin`; its relevant upstream change is only that dependency bump plus removal of unused ciphers.

`lib/features/coldcard_firmware` owns the complete app feature: failure mapping, repository contract and implementation, use cases, flow-scoped composition, Cubit/state, routing, and UI. It consumes the package's public domain types directly. There are no duplicate app entities, mappers, or `lib/core/coldcard_firmware` stack.

## Flow-scoped repository session

The repository is deliberately a session object: one instance is created per Coldcard firmware Cubit and shared by that flow's use cases. Its required call order is:

```text
fetchLatest(model) → downloadAndVerify() → saveVerifiedFirmware()
```

- `fetchLatest(model)` clears old session state, fetches the latest release, and privately caches that exact `FirmwareRelease`.
- `downloadAndVerify()` takes no release argument. It fails closed unless discovery succeeded, clears any previous verified result, downloads the cached release, verifies it, and privately caches the resulting package `VerifiedFirmware`.
- `saveVerifiedFirmware()` takes no bytes or firmware argument. It fails closed unless verification succeeded and writes only the privately cached `VerifiedFirmware.bytes` under the verified release's original filename.
- Cancellation is idempotent. Starting a new fetch/download or closing the flow invalidates state that must not cross sessions. Picker cancellation and completed exports may retain the verified result so the user can choose another destination without downloading again.

This temporal coupling is intentional: callers cannot substitute a stale release or construct bytes that reach export. The package's opaque verdict remains behind the repository boundary rather than being copied into a publicly constructible app type.

## Trust and release facts

- Manifest: `https://raw.githubusercontent.com/Coldcard/firmware/master/releases/signatures.txt`, a PGP-clearsigned, append-only list of SHA-256 hashes and filenames.
- Signing key: Peter D. Gray (`DocHex`), fingerprint `4589 779A DFC1 4F33 2753 4EA8 A3A3 1BAD 5A2A 5B10`.
- The armored key was derived independently from Keybase and the Ubuntu keyserver; both copies produced the pinned fingerprint, and GPG accepted the live manifest signature. The keyserver copy is embedded byte-for-byte with provenance instructions for reviewers.
- The key is compiled in and never fetched at runtime. Verification requires both a valid signature from the pinned key and a SHA-256 match for the exact downloaded filename.
- Downloads-page HTML is discovery input, not a trust source. A release is offered only after it appears in the verified manifest.
- Edge (`X`) and `-factory` images are rejected. Q and Mk4 have separate version spaces; Mk4 accepts the historical `-mk4-` and current `-mk-` filename forms. The package owns parsing of the filename timestamp through `FirmwareRelease.releasedAt`.
- Coldcard's bootloader remains the final authority and independently checks the embedded firmware signature during installation and boot.

## App behavior

- The verified screen displays the package-provided release and signer identity.
- Export uses the system file picker, including supported microSD/USB-OTG destinations, and preserves the original filename.
- A missing or wrong-type device route argument redirects to model selection instead of throwing.
- Expected package exceptions are mapped to feature failures; unexpected `Exception`s are logged with their stack trace and mapped safely. Programmer `Error`s are not caught.
- A fresh discovery clears the previously displayed release so retry cannot download stale metadata.

## Verification evidence and merge checks

The pure-Dart package has offline coverage for all historical supported filename shapes, Q/Mk4 version isolation, signed-manifest parsing, discovery fallback, bounded download/progress, wrong-key rejection, manifest tampering, injected manifest lines, firmware-byte tampering, and the pinned key's self-consistency. Fixtures include real Coldcard pages and manifest data plus a throwaway signing key, so cryptographic success and failure paths run without Coinkite's private key.

Production end-to-end checks discovered, downloaded, and verified Q v1.4.1Q (1.07 MB) and Mk4 v5.5.1 (1.0 MB) in roughly 2–4 seconds each.

App tests cover repository session preconditions, use-case delegation, Cubit stale-retry/cancellation/export transitions, failure mapping, and guarded routing. Before merge, run:

```bash
make build-runner
(cd packages/coldcard_firmware && fvm dart test)
make checks
```

Also exercise discovery, download, verification, picker cancellation, repeat export, back-navigation during download, and offline retry on a device or emulator. Any unrelated timezone-sensitive CSV baseline failure should be reproduced under UTC and kept outside this change.
