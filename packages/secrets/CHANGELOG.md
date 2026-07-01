# Changelog

All notable changes to the `secrets` package. This package is unpublished
(`publish_to: none`); versions track the internal refactor milestones.

## 0.1.0 (unreleased)

Initial sealed-package extraction — the sole owner of user secret material
(mnemonics, seed bytes, xprv) for the Bull wallet. Not yet consumed by the app
(`lib/` imports nothing from here); see `ADOPTION.md`.

### Public API
- `Secrets` static entry point (`init`, `importMnemonic`, `generateMnemonic`,
  `fingerprintOfMnemonic`, `fetch`, `list`, `exists`, `restoreVault`).
- Sealed `Secret` capability handle (`MnemonicSecret` / dormant `SeedSecret`) —
  derivation, signing (intent-gated), swaps (commitment-asserted), backup vault,
  BIP85/Ark, `delete`. Holds no words/bytes; each op is use-and-forget.
- Sealed display widgets: `SecretRevealer`, `VerifyBackupView`,
  `Bip85MnemonicView`, `Bip85HexView`.
- `SecretsFailure` family (returned) + `SecretsError` family (thrown, precondition
  bugs); the app implements the one injected `SecretIndexPort`.

### Storage backends
- `FssSecretStoreAdapter` (`flutter_secure_storage`) and the hardware-backed
  `OublietteSecretStoreAdapter` (iOS/Android) behind the internal `SecretStorePort`.
- `Secrets.init({mode})` probes device capability and wires FSS-only or a
  `DualReadStore` (hardware-first read, FSS fallback); `Secrets.probeBackend()`
  runs the census standalone; `Secrets.migrateToHardware()` does the one-time
  FSS→hardware copy (`MigrationReport`).
- `init` is **async** and returns a `SecretsInitResult` (`{outcome, probeError}`).

### Reliability
- `Secrets.reconcile()` heals store↔index drift at startup: re-indexes
  `seed_<fp>` orphans (and rebuilds the whole index if the DB is lost); surfaces
  danglers, legacy-scheme keys, and malformed keys without dropping them
  (`ReconcileReport`). Returns `Err` (defers) on a locked keychain.

### Security
- Library-privacy + non-export + `make seal-check` seal; no-secret-logging
  (runtime type names only); redacted `toString`, no `toJson`; buffer zeroing on
  every FSS read and during migration. Bitcoin signing is intent-gated with
  `trustWitnessUtxo: false`; swap lockups are asserted to commit to the caller's
  own derived key. See the README "Threat model" for the seal's non-goals.
