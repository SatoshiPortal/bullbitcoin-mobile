# Coldcard Firmware Update Tool — Implementation Plan

**Issue:** SatoshiPortal/bullbitcoin-mobile#1260 (CKCC support) — MVP slice
**Status:** Plan approved decisions locked 2026-07-13; not started
**Research basis:** verified against coldcard.com, Coldcard/firmware, ckcc-protocol, rust-coldcard (2026-07-13)

## 1. Scope (MVP)

User story:

> Settings → Bitcoin settings → Coldcard firmware update → Select device type → We look up the latest firmware available and display it → Download firmware button → Spinner while in progress → We check the hash and the signature against the Coldcard signing keys → Green checkmark showing it's verified → Export button saves it to device storage or SD card

Out of scope for MVP (later phases of #1260): USB device listing, bag number, automated USB upgrade, sign message, USB PSBT flow. These need the CKCC USB protocol (Android-only via `quick_usb`; iOS has no third-party USB HID). The package structure below leaves room for them.

## 2. Locked design decisions

1. **Version discovery:** scrape the coldcard.com model downloads page for the currently-offered release, then **require** that exact filename+hash to appear in the PGP-verified `signatures.txt`. Fallback to max-version-from-signatures.txt if the scrape breaks (surface a warning in logs).
2. **Tor:** clearnet only for MVP. When Tor is added later: follow app setting, never silently fall back Tor→clearnet.
3. **Location:** pure-Dart package under `packages/` (analyzer-enforced zero Flutter deps), wired into the workspace like `packages/bull_ui`. UI/bloc in `lib/features/coldcard_firmware/`.
4. **PGP:** `dart_pg`, exact version pinned in pubspec (`dart_pg: 2.1.0`, no caret). Independent SHA-256 recompute via `crypto` as defense-in-depth.

## 3. Reference facts (verified 2026-07-13)

### Distribution
- Binaries: `https://coldcard.com/downloads` — per-model pages `/downloads/q1` (Q), `/downloads/mk` (Mk4 current line), `/downloads/mk4`, `/downloads/mk3`; history `/downloads/all`. Direct URL: `https://coldcard.com/downloads/<FILENAME>.dfu`.
- No JSON/atom API exists. Discovery = HTML scrape for `.dfu` hrefs.
- Manifest: `https://raw.githubusercontent.com/Coldcard/firmware/master/releases/signatures.txt` — PGP **clearsigned**, body is `sha256sum` format: `<64-hex sha256>  <filename>` per line, append-only history of every release.

### Filename grammar
```
<YYYY-MM-DDTHHMM>-v<VERSION>[Q|X]-<MODEL>-coldcard[-factory].dfu
  MODEL:   q1 = Coldcard Q | mk = Mk4 line since v5.5.0 (2026-03) | mk4 = Mk4 ≤ v5.4.5 | mk3
  Q marker: Q builds carry Q in version (v1.4.1Q); Q version space is SEPARATE from Mk — never compare across models
  X marker: edge/experimental builds — EXCLUDE
  -factory: full factory image incl. bootloader — NEVER offer to users
```
Suggested regex: `(\d{4}-\d{2}-\d{2}T\d{4})-v(\d+\.\d+\.\d+)(Q?)(X?)-(mk4?|mk|q1)-coldcard\.dfu` (note: rust-coldcard's regex predates the Q and `-mk-` rename — do not copy it).

Current as of 2026-07-13: Mk4 line v5.5.1 (`2026-07-01T1729-v5.5.1-mk-coldcard.dfu`), Q v1.4.1Q (`2026-07-01T1727-v1.4.1Q-q1-coldcard.dfu`), Mk3 final v4.1.9.

### Verification layers
- **Host-side (ours):** verify clearsign signature of signatures.txt against bundled key of Peter D. Gray "DocHex" (Coinkite), RSA, fingerprint `4589779ADFC14F3327534EA8A3A31BAD5A2A5B10`. Sources for the armored key: keybase.io/dochex, keyserver.ubuntu.com (0xA3A31BAD5A2A5B10). Bundle the armored key as a const in the package — never fetch at runtime. After signature passes AND signer fingerprint matches the pin, extract the hash for our filename and compare to the SHA-256 of the downloaded bytes.
- **On-device (not ours):** firmware header carries secp256k1 sig checked by the bootloader against factory keys on install + every boot; device rejects tampered firmware. Monotonic BCD timestamp + high-water flag give downgrade protection. Our layer is supply-chain protection so a bad file never gets our green checkmark.
- Prior art gap we close: `rust-coldcard` checks SHA-256 only (no PGP); `ckcc upgrade` uploads local files and trusts the device. We do PGP + SHA-256.

### microSD constraints (for UI copy)
FAT32 (or FAT12), card ≤32GB. Plain `-coldcard.dfu` anywhere on card, keep original filename. Device flow: Advanced/Tools → Upgrade → From MicroSD → select file. After reboot user verifies anti-phishing words + Advanced → Upgrade → Show Version.

## 4. Deliverable 1 — `packages/coldcard_firmware` (pure Dart)

Named `coldcard_firmware` (Dart package names can't contain hyphens, so "coldcard-firmware" → `coldcard_firmware`). Scoped to exactly what it does; future CKCC USB protocol work becomes its own package when it lands.

```
packages/coldcard_firmware/
  pubspec.yaml            # deps: dio, crypto, dart_pg (pinned exact); NO flutter
  lib/
    coldcard_firmware.dart  # exports
    src/firmware/
      model.dart          # ColdcardModel enum (q, mk4, mk3) → page path + filename suffixes + version space
      release.dart        # FirmwareRelease (model, version, isEdge, timestamp, filename, downloadUrl)
      release_parser.dart # filename grammar regex, semver compare within model space
      discovery.dart      # scrape model page → offered releases; signatures.txt fallback path
      signatures.dart     # fetch + dart_pg clearsign verify + fingerprint pin + parse hash lines
      downloader.dart     # dio stream → tee into chunked SHA-256 + bytes; progress callback; size cap 20MB
      verifier.dart       # orchestrates: discovery cross-check + hash compare → VerifiedFirmware
      trusted_key.dart    # const armored DocHex pubkey + const expected fingerprint
      failures.dart       # sealed ColdcardFirmwareException
  test/
    fixtures/             # real signatures.txt snapshot, sample model-page HTML, tampered variants
    ...unit tests
```

Public API sketch:

```dart
class ColdcardFirmwareClient {
  ColdcardFirmwareClient({Dio? dio});                      // injectable for tests/Tor later
  Future<FirmwareRelease> fetchLatest(ColdcardModel model); // scrape + cross-check against verified signatures.txt
  Future<DownloadedFirmware> download(FirmwareRelease release,
      {void Function(int received, int total)? onProgress, CancelToken? cancelToken});
  Future<VerifiedFirmware> verify(DownloadedFirmware fw);   // PGP + hash; throws typed failures
}

class VerifiedFirmware {
  final FirmwareRelease release;
  final Uint8List bytes;          // ~1–2MB, held in memory until export
  final String sha256Hex;
  final String signerFingerprint; // == pinned DocHex fp
}

sealed class ColdcardFirmwareException implements Exception {}   // package-level; app maps these to its own Failure type
// NetworkFailure, DiscoveryParseFailure, ReleaseNotInManifest,
// PgpSignatureInvalid, PgpWrongKey, HashMismatch, FileTooLarge, EdgeOrFactoryRejected
```

Implementation rules:
- Filter out `X` (edge) and `-factory` at the parser level — they must be unrepresentable in `FirmwareRelease` for normal discovery.
- `fetchLatest` = scrape page → parse candidates → pick max version within the model's own version space → fetch+verify signatures.txt → the chosen filename MUST be present (else `ReleaseNotInManifest`); attach expected hash to the release. Scrape failure → fallback: max version for model straight from verified signatures.txt.
- `download` streams via dio `ResponseType.stream`, feeding chunks to `Sha256().startChunkedConversion` and a builder — single pass, constant memory; enforce 20MB cap and timeouts.
- `verify` = `OpenPGP.verify()` (dart_pg) of the clearsigned text against `OpenPGP.readPublicKey(bundledArmoredKey)`; require verification valid AND issuing key fingerprint equals pinned constant; parse body lines; exact filename match; compare hex hashes.
- Never expose unverified bytes from the public API path used by the app (download returns an opaque `DownloadedFirmware`; only `verify` yields `VerifiedFirmware`).
- HTTPS only; rely on system trust roots (PGP layer covers content integrity; no cert pinning in MVP).

Tests (all offline, fixtures):
- parser: every historical filename shape (`-mk4-`, `-mk-`, `-q1-`, Q/X markers, `-factory`), version-space isolation (Q v1.4.1 vs Mk v5.5.1 never compared)
- signatures: valid fixture passes; flipped byte in body → `PgpSignatureInvalid`; re-signed with a different key fixture → `PgpWrongKey`; missing filename → `ReleaseNotInManifest`
- downloader: hash-while-streaming correctness; size cap; progress emission
- verifier: tampered dfu bytes → `HashMismatch`

## 5. Deliverable 2 — app integration

Follow the house pattern (mirror `lib/core/ledger/` shape; ARCHITECTURE.md "Adding a feature" checklist):

```
lib/core/coldcard_firmware/
  domain/
    entities/…                       # thin re-mapping of package types if needed
    repositories/coldcard_firmware_repository.dart   # abstract interface class
    usecases/
      get_latest_coldcard_firmware_usecase.dart      # execute(model)
      download_and_verify_coldcard_firmware_usecase.dart  # execute(release, onProgress)
      save_coldcard_firmware_usecase.dart            # execute(verified) → FilePicker saveFile
  data/
    repository impl (delegates to ColdcardFirmwareClient)
  coldcard_firmware_locator.dart

lib/features/coldcard_firmware/
  presentation/  # bloc/cubit: states = selectModel → checking → latestShown → downloading(progress)
                 #   → verifying → verified → exporting → exported | failure(step, retryable)
  ui/            # screens per user story; green checkmark shows version + sha256 (first/last 8 chars)
                 #   + "Signed by Coinkite (DocHex)"; microSD instructions copy (FAT32 ≤32GB, device menu path)
  coldcard_firmware_router.dart
```

Wiring: `lib/locator.dart` (+`ColdcardFirmwareLocator.setup`), `lib/router.dart` spread, Settings → Bitcoin settings entry, l10n strings via `make translations`, failures via sealed `ColdcardFirmwareFailure extends Failure` + `_failure_l10n.dart`.

Save/export: reuse the `FilePicker.platform.saveFile(bytes:, fileName: release.filename)` pattern (see `lib/core/recoverbull/domain/usecases/save_file_to_system_usecase.dart`). Original filename preserved. On Android SAF this reaches microSD incl. USB OTG readers; on iOS the Files picker.

Device selector: reuse `SignerDeviceEntity` display names (`coldcardQ`, `coldcardMk4`); add Mk3 as a static "final release v4.1.9" entry (decide in PR3 whether to show it).

## 6. PR breakdown (stacked)

| PR | Content | Notes |
|----|---------|-------|
| PR1 | `packages/coldcard_firmware`: models, parser, discovery, signatures verify, downloader, verifier, fixtures + full unit suite; workspace wiring in root pubspec | Pure Dart. Reviewable standalone; the security-critical PR — review `trusted_key.dart` + `signatures.dart` hardest. Verify bundled key fingerprint out-of-band (keybase.io/dochex + keyserver) at review time |
| PR2 | `lib/core/coldcard_firmware/`: repository, usecases, locator, failures + unit tests (mock package client) | No UI; small |
| PR3 | `lib/features/coldcard_firmware/`: bloc, screens, router, Settings entry, l10n, failure l10n | UI per user story |

Estimate: PR1 ~2–3 days, PR2 ~1 day, PR3 ~2–3 days.

## 7. Verification plan (before merge of PR3)

1. Unit suites green (`make unit-test`).
2. Manual e2e: real device build → Q selected → v-latest shown matches coldcard.com → download → verified checkmark → export to microSD via USB reader → flash a real Coldcard Q (Advanced → Upgrade → From MicroSD) → green boot light → Show Version matches.
3. Negative: airplane-mode mid-download (clean failure+retry); fixture-swap test in debug build proving tampered manifest and tampered bytes both fail closed.

## 8. Security checklist

- [ ] DocHex key bundled as const; fingerprint pin checked on every verify; no runtime key fetch
- [ ] `dart_pg` pinned to exact version; note in pubspec comment why
- [ ] `-factory` and `X` builds unrepresentable in discovery results
- [ ] No unverified bytes reachable by export path (type-level: only `VerifiedFirmware` is saveable)
- [ ] Size cap + timeouts on all fetches; HTTPS only
- [ ] Q/Mk version spaces never cross-compared
- [ ] UI shows version, truncated hash, signer identity on the verified screen
- [ ] Failure states fail closed (any error → no checkmark, no export button)

## 9. Open items (non-blocking)

- Show changelog/release notes? (`releases/ChangeLog.md` in Coldcard/firmware is per-release; skip for MVP, link out instead.)
- Offer Mk3 (final v4.1.9) in the device selector, or Q + Mk4 only?
- Package publish to pub.dev after it stabilizes (open-source announcement angle).
