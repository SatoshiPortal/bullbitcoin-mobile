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

| Contract | Returns (all `Result<_, SecretsFailure>`) |
|---|---|
| `SeedRepository` | seed lifecycle → `Fingerprint` / `SeedInfo` (never the seed) |
| `KeyDerivationPort` | `Xpub`, `BitcoinDescriptor`, `LiquidDescriptor` (watch-only) |
| `SignerPort` | `SignedPsbt` — validates a `SigningIntent` BEFORE signing |
| `SwapSignerPort` | `CreatedSwap` — asserts the lockup commits to your key |
| `BackupVaultPort` | `EncryptedVault` + `BackupKey` / restored `Fingerprint`s |
| `Bip85Port` | sealed `Bip85Derivation` / `Bip85HexResult`, `BackupKey`, `ArkSecret` |
| Widgets | `MnemonicView`, `VerifyBackupView`, `Bip85MnemonicView`, `Bip85HexView` |

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
   boundary sanitizes `logMessage` (12/24-word + 64-hex + xprv) before logging.

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
  internal `SecretStore` seam.
- **Liquid signing** enforces the fee cap (the only soundly-checkable invariant
  on confidential outputs); per-output change-ownership is not provable on
  blinded outputs and is a documented residual. Liquid uses an ephemeral temp
  LWK db deleted after signing.

## Storage

FSS-only today (`FssSecretStore` over `flutter_secure_storage`). The internal
`SecretStore` port is use-and-forget shaped so a hardware backend drops in
unchanged. The non-secret `SeedIndex` (app-side Drift) is reconciled against the
store at startup; drift is surfaced, never silently dropped.

## Wiring

```dart
SecretsLocator.registerDatasources(locator);   // FssSecretStore + MnemonicReader
// app registers its Drift-backed SeedIndex here
SecretsLocator.registerRepositories(locator);   // the 6 ports (asserts SeedIndex)
```

See `SECRETS_REFACTORING_SPEC.md`, `SECRETS_IMPLEMENTATION_AUDIT.md`, and
`SECRETS_FILE_BY_FILE_AUDIT.md` at the repo root for the full design + audit.
