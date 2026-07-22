# coldcard_firmware

Pure-Dart library to discover, download and verify **Coldcard** firmware against Coinkite's PGP-signed release manifest. No Flutter dependency — usable from the app, a CLI, or tests alike.

## What it does

```dart
final client = ColdcardFirmwareClient();

// 1. What's the latest firmware for this device?
final release = await client.fetchLatest(ColdcardModel.q);
print('${release.version} — ${release.filename}');

// 2. Download it (streamed, size-capped, with progress).
final downloaded = await client.download(
  release,
  onProgress: (received, total) => print('$received/$total'),
);

// 3. Verify. Throws unless BOTH checks pass:
//    - signatures.txt carries a valid PGP signature by the pinned Coinkite signing key (bundled at compile time), and
//    - the downloaded bytes hash to the entry that signed manifest promises for this exact filename.
final verified = await client.verify(downloaded);

// Pass verified itself to the app's export/save boundary.
// Do not reconstruct it from copied fields or bytes.
// verified.sha256Hex / verified.signerFingerprintHex → show the user.
```

Every failure is a typed `ColdcardFirmwareException` subtype (`ManifestSignatureException`, `FirmwareHashMismatchException`, ...) so the UI can fail closed and explain why.

## Trust model

- **Trust anchor:** Coinkite's release-signing key (Peter D. Gray, fingerprint `4589 779A DFC1 4F33 2753 4EA8 A3A3 1BAD 5A2A 5B10`) is **compiled in** (`lib/src/firmware/trusted_key.dart`) and never fetched at runtime. Reviewers of any change to that file must re-derive the fingerprint from independent sources (keybase.io/dochex + a keyserver).
- **The verdict types are unforgeable through the API:** `DownloadedFirmware` and `VerifiedFirmware` have private constructors, so the only path to a `VerifiedFirmware` is `verify()`. Verification recomputes the SHA-256 over a private copy of the bytes and returns that copy as an unmodifiable list, so neither a lying hash field nor later mutation can produce or corrupt a verified result. The app's export boundary should consume the package's `VerifiedFirmware` directly rather than reconstructing it from fields.
- **No security knob is exported:** the trust anchor, verifier and endpoints are fixed in the public constructor, and the barrel exports an explicit `show` list. Package-owned tests deliberately import an internal, `@visibleForTesting` factory to use local endpoints and a throwaway key; the annotation documents its scope and the public barrel does not expose it.
- **Discovery is untrusted:** the coldcard.com downloads page is scraped only to learn what's currently offered; nothing is reported to the caller unless the filename also appears in the verified manifest. Metadata fetches are size-capped and the default HTTP client has connect/receive timeouts, so an oversized or stalled response fails instead of hanging or exhausting memory.
- **Defense in depth:** the SHA-256 check with `package:crypto` is independent of the PGP layer (`dart_pg`, pinned to an exact version).
- **The device is the final authority:** Coldcards verify the firmware's embedded signature against factory keys at install and on every boot. This library is the supply-chain gate in front of that, not a replacement for it.
- Edge (`X`) and `-factory` builds are filtered out at the parser level and can never be offered.

## Notes

- Firmware filenames follow `<YYYY-MM-DDTHHMM>-v<version>[Q][X]-<model>-coldcard[-factory].dfu`; the Mk4 line renamed its suffix `-mk4-` → `-mk-` at v5.5.0 and both are accepted. Q's version space (v1.x) is unrelated to Mk4's (v5.x) — versions are only compared within one model.
- There is no machine-readable release index upstream; when the page scrape fails to parse, discovery falls back to the newest entry in the signed (append-only) manifest.
- Tests run offline against snapshotted fixtures: `fvm dart test` in this directory. See `test/fixtures/README.md`.
