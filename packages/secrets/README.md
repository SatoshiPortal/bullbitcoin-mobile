# `secrets`

The **sole owner of user secrets** (seed bytes, mnemonics, xprv) for the Bull
wallet. Nothing outside this package can read raw secret material — callers get
non-secret info, operation results, or sealed display widgets.

## The rule

> Raw secret material has **no path out** of the package. You hand `secrets` a
> `Fingerprint` (a public handle) and get back an `Xpub`, a `SignedPsbt`, an
> `EncryptedVault`, a `CreatedSwap`, or a sealed widget — never the words or the
> bytes.

## What you get

| Port (interface) | Returns (all `Result<_, SecretsFailure>`) |
|---|---|
| `SeedPort` | seed/mnemonic lifecycle → `Fingerprint` / `SeedInfo` (never the secret) |
| `KeyDerivationPort` | `Xpub`, `BitcoinDescriptor`, `LiquidDescriptor` (watch-only) |
| `SignerPort` | `SignedPsbt` — validates a `SigningIntent` BEFORE signing |
| `SwapSignerPort` | `CreatedSwap` — asserts the lockup commits to your key |
| `BackupVaultPort` | `EncryptedVault` + `BackupKey` / restored `Fingerprint`s |
| `Bip85Port` | sealed `Bip85Derivation` / `Bip85HexResult`, `BackupKey`, `ArkSecret` |
| Widgets | `MnemonicView`, `VerifyBackupView`, `Bip85MnemonicView`, `Bip85HexView` |

## Naming & layering (this package's convention)

Ports-and-adapters, enforced by `make seal-check`:

- **`*Port`** — an interface (the public capability contract), in `src/domain/ports/`.
- **`*Adapter`** — its implementation, in `src/data/adapters/` (internal, never
  exported). Multiple backends are tech-prefixed: `FssSecretStoreAdapter` today,
  `OublietteSecretStoreAdapter` tomorrow; the app's Drift `SeedIndexPort`
  implementation is `DriftSeedIndexAdapter`.
- **Mnemonic vs Seed.** The *stored* secret is a `Mnemonic` (words + optional
  passphrase + language). A `Seed` is the *derived* PBKDF2 bytes (hex-only, no
  words). Only mnemonics are stored today; the storage format is discriminated
  so a future raw-`Seed` import slots in without a break. Both are internal.
- Folders speak the layered language: `domain/ports` + `domain/value_objects`
  (interfaces + entities), `data/adapters` + `data/models` (impls + the secret
  model), `crypto` (pure derivation/validation, no I/O). A `*Port` = the app's
  "repository interface"; a driven-port adapter wrapping one external system
  (`FlutterSecureStorageAdapter`) = the app's "datasource".

## How the seal works

1. **Library privacy + non-export** (the hard wall): raw-secret code lives under
   `src/`, never exported from `lib/secrets.dart`. A cross-package
   `import 'package:secrets/src/...'` is an `implementation_imports` info →
   fatal under CI's `--fatal-infos`.
2. **`@internal` accessors** for the few secret-bearing payloads that must cross
   the barrel (`Bip85Derivation.words`, `Bip85HexResult.hexForView`,
   `ArkSecret.bytes`) — external use trips `invalid_use_of_internal_member`.
3. **`make seal-check`** — CI gate against external `src/` imports, internal
   barrel exports, and suppression of the internal-member lint.
4. **Redacted `toString` + no `toJson`** on every secret-bearing type; the
   boundary never logs secret-bearing text — a foreign exception contributes
   only its runtime *type* name (never its message) to `logMessage`, alongside
   the public fingerprint.

## Security guarantees (and honest limits)

- **Signing is intent-gated** (`IntentValidator`, issue #1703): a send rejects an
  over-cap fee, a non-wallet input, a duplicated/missing/exfiltration output;
  payjoin enforces the BIP78 checklist (fail-closed); a swap asserts the lockup
  script commits to your own derived key (the Boltz address is untrusted).
- **`trustWitnessUtxo: false`** on Bitcoin signing; FSS uses `resetOnError:false`
  + `AfterFirstUnlockThisDeviceOnly`; `KeychainLockedFailure` is never collapsed
  into `SeedNotFoundFailure`.
- **At rest only** is hardware-adjacent: BIP32/39/85 are pure Dart, so the seed
  transits the Dart heap during each derive/sign and **cannot be zeroized**
  (moving GC). A hardware backend (oubliette) is a future initiative behind the
  internal `SecretStorePort` seam.
- **Liquid signing** enforces the fee cap (the only soundly-checkable invariant
  on confidential outputs); per-output change-ownership is not provable on
  blinded outputs and is a documented residual. Liquid uses an ephemeral temp
  LWK db deleted after signing.
- **Backup vault** is **not** AEAD. The pinned third-party `recoverbull` uses
  AES-256-CBC + HMAC-SHA256 (encrypt-and-MAC, one key shared by cipher and MAC),
  and the surrounding JSON envelope (`createdAt`/`id`/`salt`) is unauthenticated.
  Each backup gets a fresh `Random.secure()` IV and a fresh per-backup BIP85
  `BackupKey` (no IV/key reuse), and tamper/wrong-key is detected via a
  constant-time MAC compare — so it is sound-but-not-AEAD. Hardening (HKDF
  enc/MAC key separation, full-envelope MAC) is an upstream `recoverbull` concern.

## Storage

FSS-only today (`FssSecretStoreAdapter` over `flutter_secure_storage`). The internal
`SecretStorePort` is use-and-forget shaped so a hardware backend drops in
unchanged. The non-secret `SeedIndexPort` (app-side Drift) is reconciled against the
store at startup; drift is surfaced, never silently dropped.

## Wiring

```dart
SecretsLocator.registerDatasources(locator);   // FssSecretStoreAdapter + MnemonicReader
// app registers its Drift-backed SeedIndexPort here
SecretsLocator.registerRepositories(locator);   // the ports (asserts SeedIndexPort)
```
