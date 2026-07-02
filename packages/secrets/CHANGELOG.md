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
  every FSS read, on the main write, and during migration. Bitcoin signing is
  intent-gated with `trustWitnessUtxo: false`; swap lockups are asserted to commit
  to the caller's own derived key. See the README "Threat model" for the seal's
  non-goals.
- **Backup vault:** `encryptVault({vaultKey})` takes the key as an INPUT and
  returns ONLY the ciphertext — the key is never co-returned, so one call can't
  hand a caller both halves of recoverbull's two-location model.
- **Swaps:** caller-knowable `SwapRequest` types (`ReverseSwapRequest` /
  `SubmarineSwapRequest` / `ChainSwapRequest`) replace the unconstructible
  `SwapIntent`; the package builds the commitment from the SDK swap (own key(s),
  `preimage.sha256`, locktime) and gates the amount per type. `CreatedSwap`
  exposes `preimageSha256` / own pubkey(s) / `lockupLocktime`.
- **Liquid signing** additionally checks that every declared recipient script is
  present (blocking address substitution) and fails closed when no output scripts
  can be extracted; `hasPassphrase` wallets are rejected on both Liquid and swap
  paths (the bare-mnemonic derivation would use a different wallet).
- **Storage:** a persistent-null FSS read while the key still exists surfaces as
  locked (not not-found); locked-keychain detection is separator-insensitive
  (the bare `-25308` status matched only as the whole code); migration verifies
  by reading bytes back, re-checks BOTH the FSS store and the index before
  storing (no delete-race resurrection), and reports un-indexed FSS orphans so
  `complete` stays honest.
- **Migration is fully distrustful of hardware presence:** an already-present HW
  copy is byte-verified against the retained FSS copy on the skip path, and ANY
  verify-stage failure (mismatch, corrupt ciphertext, crash-then-rerun) trashes
  the bad HW copy and re-migrates — so an unverified/corrupt copy can never
  count `skipped` and flip `complete` true (the gate for wholesale FSS removal),
  nor shadow the good FSS copy.
- **Fresh writes are verified:** `importMnemonic`/`generateMnemonic` read the
  seed back (through the sealed guard) before indexing and fail closed if it
  doesn't decode to the same fingerprint — a silently-dropped/corrupt write is
  never reported as a stored seed.
- **`liquidDescriptor` rejects passphrase wallets** (like signing/swaps), so it
  never returns a bare-seed Liquid wallet the package can't sign for.
- **Probe won't strand hardware seeds:** an `autoDetect` downgrade to FSS-only
  is refused when the hardware store already holds seed keys.
- **`Bip85Path`/recoverbull paths** strip the BIP85 root purpose (`83696968'`),
  so an absolute path no longer misreads the root as the application number.
- All git deps SHA-pinned in the member pubspec too (`bull_sdk` no longer tracks
  the moving `main`).
