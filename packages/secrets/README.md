# `secrets`

The **sole owner of user secrets** (mnemonics, seed bytes, xprv) for the Bull wallet. Nothing outside this package can read raw secret material **through its public (exported) API** — callers get non-secret metadata, operation results, or sealed display widgets.

## The rule

> Raw secret material has **no path out** through the package's **public API**. You hold a `Secret` handle (identified by a `Fingerprint`) and call methods on it; you get back an `Xpub`, a `SignedPsbt`, an `EncryptedVault`, a `CreatedSwap`, a `Bip85Derivation`, or a sealed widget — never the words or the bytes.
>
> The few raw-secret seams that must exist for the sealed display widgets (e.g. the `@internal` `Secrets.mnemonicReader`) are **not** part of that public API: reaching them from outside the package is blocked by library-privacy + the `@internal` lint (`--fatal-infos`) + `make seal-check`. That is a **compile/CI-time** wall enforced by convention and tooling, **not** an absolute type-system guarantee — see the threat-model note below.

## Using the package

`secrets` is consumed as a **library**, not a DI container. One import, one-time `init`, then static creation plus a `Secret` handle:

```dart
import 'package:secrets/secrets.dart';

// Once, at app start. `index` is the app's SecretIndexPort (Drift-backed);
// it stores only NON-secret metadata. `store` is optional (a test seam).
await Secrets.init(index: DriftSecretIndex());
```

`init` is **async** and returns a `SecretsInitResult` (`{outcome, probeError}`) describing which storage backend was wired; it also accepts an optional `mode` (`SecretsStorageMode.autoDetect` | `oublietteFirst` | `fssOnly`, default `autoDetect`) — see [Storage](#storage). Calling a `Secret`-operating member before `init` throws a `StateError` (the sole exception is `Secrets.probeBackend`, which deliberately runs a standalone capability probe *without* wiring the package). The single re-exported import (`package:secrets/secrets.dart`) also brings in the `primitives` types used in signatures (`Fingerprint`, `BitcoinNetwork` / `LiquidNetwork` / `NetworkEnv`, `ScriptType`, `XpubType`, `Result` / `Ok` / `Err`) — a consumer never imports `primitives`, `src/`, or any DI library directly.

### Entry points — the static `Secrets` API

Every async *secret* op returns `Future<Result<T, SecretsFailure>>`. (The wiring/telemetry statics — `init`, `probeBackend`, `migrateToHardware` — return backend/report records instead, not a `Result`.)

| Static | Returns | Purpose |
|---|---|---|
| `Secrets.init({index, mode, store?})` | `Future<SecretsInitResult>` | Build the internal graph once, choosing the storage backend per `mode`; returns the resolved backend outcome. |
| `Secrets.importMnemonic(words, {passphrase, language})` | `MnemonicSecret` | Import existing words, store, return the typed handle. |
| `Secrets.generateMnemonic({length})` | `MnemonicSecret` | Generate fresh words, store, return the handle. |
| `Secrets.fingerprintOfMnemonic(words, {passphrase, language})` | `Fingerprint` | Derive the fingerprint **without** storing (duplicate pre-check). |
| `Secrets.fetch(fp)` | `Secret` | Read the index → typed handle, or `SecretNotFoundFailure`. Never touches the secret store. |
| `Secrets.list()` | `List<Secret>` | All stored secrets, as handles. |
| `Secrets.exists(fp)` | `bool` | Whether a secret with `fp` is stored. |
| `Secrets.restoreVault({vault, vaultKey})` | `List<Fingerprint>` | Decrypt a vault in-package, write the recovered secret(s), return their fingerprints. |
| `Secrets.reconcile()` | `Result<ReconcileReport, …>` | Heal store↔index drift at startup: re-index store-orphans; report danglers/malformed keys (never dropped). |
| `Secrets.migrateToHardware()` | `MigrationReport?` | One-time FSS→hardware seed copy when a hardware backend is active (else `null`). |
| `Secrets.probeBackend()` | `Future<SecretsInitResult>` | Probe device hardware-storage capability **without** wiring the seed layer (standalone census). |

`importMnemonic` / `generateMnemonic` return the precise subtype (`MnemonicSecret`), so you can operate immediately without a second `fetch`. `fetch` resolves the kind from the index and returns the base `Secret` (narrow with `is MnemonicSecret`).

### The `Secret` handle

A `Secret` is a **capability handle** over a stored secret. It carries only NON-secret metadata (from the index) and the operations every secret-bearing kind supports. The object holds **no words and no bytes** — each method does its own use-and-forget read internally and discards the material. Handle methods take **no `fingerprint` argument**; the handle already *is* the identity.

Metadata getters:

- `Fingerprint get fingerprint`
- `SecretKind get kind` (`mnemonic` | `seed`)
- `bool get hasPassphrase`
- `DateTime? get createdAt`
- `SecretInfo get info` — the raw index record it composes

Operations (all `Future<Result<…, SecretsFailure>>`):

- **Derivation** — `xpub({scriptType, network, account})`, `bitcoinDescriptor({scriptType, network})`, `liquidDescriptor({network})`
- **Signing** — `signBitcoin({psbt, intent, scriptType, network})`, `signLiquid({pset, intent, network})` (intent-gated; see below)
- **Swaps** — `createBtcReverse(…)`, `createBtcSubmarine(…)`, `createLbtcReverse(…)`, `createLbtcSubmarine(…)`, `createChainSwap(…)` (each returns a `CreatedSwap` whose lockup is asserted to commit to your own derived key)
- **Backup vault** — `encryptVault({vaultKey})` → `EncryptedVault` (the key is a caller-supplied **input**, never co-returned with the ciphertext)
- **BIP85** — `bip85ChildMnemonic({length, index})`, `bip85Bip39Child({app, index, length})`, `bip85Hex({numBytes, index})`, `bip85RecoverbullKey({path})`, `bip85Ark()`
- **Lifecycle** — `delete()` (removes the secret and its index row)

Signing/derivation/BIP85/vault live on the **base** `Secret` — every secret-bearing kind is a BIP32 root and can do them.

### Subtypes

The sealed hierarchy is the terminology split made into types:

- **`MnemonicSecret extends Secret`** — a stored mnemonic; adds `int get wordCount`, `String get language`.
- **`SeedSecret extends Secret`** — a stored bytes/hex seed. **DORMANT**: no bytes-import path is built yet, so this is reachable only once the seed-import seam lands.

Narrowing is how you reach subtype metadata; the compiler blocks `wordCount` on a bare `Secret` until you narrow:

```dart
if (secret case MnemonicSecret m) {
  print('${m.wordCount} words · ${m.language}');
}
```

### Display — `SecretRevealer`

Display is **not** a handle method (the handle returns data, never words/bytes). It is a single polymorphic sealed widget that does all conditional rendering from the secret itself — words grid (with the passphrase row only when one is stored) for a mnemonic, plus unavailable/locked states. (The `SeedSecret`/hex branch is **dormant** until the bytes-import seam lands — see [Subtypes](#subtypes) — so today it renders a no-phrase card.) Every branch is `PrivacyGuard`-wrapped and reads via the internal use-and-forget path.

```dart
SecretRevealer(secret: secret, strings: strings); // strings = localized labels only
```

`SecretRevealerStrings` supplies the localized UI labels the package itself cannot translate (e.g. "phrase unavailable"); it is **not** the passphrase (that comes from storage with the words). The other sealed widgets — `VerifyBackupView` (a re-entry/confirmation flow), `Bip85MnemonicView` and `Bip85HexView` (render *derived* BIP85 payloads) — stay separate.

## A realistic example

```dart
import 'package:secrets/secrets.dart';

Future<Widget> showWallet(Fingerprint fp, SecretRevealerStrings strings) async {
  final res = await Secrets.fetch(fp);
  if (res case Ok(value: final secret)) {
    // Derive a watch-only descriptor (no secret leaves the package).
    final d = await secret.bitcoinDescriptor(
      scriptType: ScriptType.bip84,
      network: BitcoinNetwork.mainnet,
    );

    // Subtype metadata needs narrowing — the compiler enforces it.
    if (secret case MnemonicSecret m) {
      debugPrint('${m.wordCount} words · ${m.language}');
    }

    // Display any kind through the one sealed widget.
    return SecretRevealer(secret: secret, strings: strings);
  }
  return const SizedBox.shrink(); // res is Err(SecretNotFoundFailure | KeychainLockedFailure | …)
}
```

## Terminology — mnemonic vs seed (one-way)

The public surface keeps three words distinct, and the names encode the asymmetry:

- **Secret** — the stored root secret, *either kind*; the neutral umbrella (matches the package name). Exposed as the `Secret` handle.
- **Mnemonic** — *words* (+ passphrase + language). A mnemonic derives a seed via PBKDF2.
- **Seed** — *bytes/hex* (the PBKDF2 output / raw entropy). A seed can **never** recover a mnemonic — the derivation is one-way.

Naming a `Fingerprint` "seed" would conflate the two, so the public API never does: `Secrets` statics take a positional `Fingerprint`, and handle methods take none.

## Chain-typed networks

Networks are typed by chain, not by a boolean soup. Two independent enums share an environment:

- `enum NetworkEnv { mainnet, testnet, signet, regtest }`
- `enum BitcoinNetwork { mainnet, testnet, signet, regtest }` (each carries its `env`; `coinType` 0 on mainnet, 1 otherwise)
- `enum LiquidNetwork { mainnet, testnet, regtest }` (no signet — Liquid lacks the value; `coinType` 1776 / 1)

Because each chain is its own type, **a wrong-chain network is a compile error** — `bitcoinDescriptor` takes a `BitcoinNetwork`, `liquidDescriptor` a `LiquidNetwork`, and `createChainSwap` takes a `NetworkEnv`. No runtime guard, no exhaustiveness dependency.

## Naming & layering (this package's convention)

Ports-and-adapters internally, enforced by `make seal-check`:

- **`*Port`** — an internal capability interface, in `src/domain/ports/`.
- **`*Adapter`** — its implementation, in `src/data/adapters/` (internal, never exported). Multiple backends are tech-prefixed: `FssSecretStoreAdapter` today, a hardware-backed adapter tomorrow; the app's Drift `SecretIndexPort` implementation is its own adapter.
- Folders speak the layered language: `domain/ports` + `domain/value_objects` (interfaces + entities), `data/adapters` + `data/models` (impls + the secret model), `crypto` (pure derivation/validation, no I/O).
- The only port a consumer ever names is **`SecretIndexPort`** — the app *implements* it (a Drift-backed, NON-secret index of `SecretInfo`). Everything else is built behind `Secrets.init`.

## How the seal works

1. **Library privacy + non-export** (the hard wall): raw-secret code lives under `src/`, never exported from `lib/secrets.dart`. A cross-package `import 'package:secrets/src/...'` is an `implementation_imports` info → fatal under CI's `--fatal-infos`.
2. **`@internal` accessors** for the few secret-bearing payloads that must cross the barrel (`Bip85Derivation.words`, `Bip85HexResult.hexForView`, `ArkSecret.bytes`) — external use trips `invalid_use_of_internal_member`.
3. **`make seal-check`** — CI gate against external `src/` imports, internal barrel exports, and suppression of the internal-member lint. Its `useAndForget` allow-list covers exactly two categories: the raw-secret **readers** (`secret_guard.dart`, `mnemonic_reader.dart`) and the `SecretStorePort` **implementations/decorators** (`oubliette_secret_store_adapter.dart`, `dual_read_store.dart`, `secret_migrator.dart`).
4. **Redacted `toString` + no `toJson`** on every secret-bearing type; the boundary never logs secret-bearing text — a foreign exception contributes only its runtime *type* name (never its message) to `logMessage`, alongside the public fingerprint.

### Threat model — what the seal is, and is NOT

The seal is a **first-party blast-radius / API boundary**, not a runtime privilege boundary. It is enforced entirely at compile/CI time (library-privacy + non-export + `make seal-check`).

- **It DOES** stop accidental first-party misuse: a teammate can't `import` `src/`, re-export an internal, grow the raw-read surface, or log a secret's text without failing CI. It shrinks the code that can touch raw material to a tiny, reviewed set of files, and keeps secret lifetime minimal (use-and-forget + buffer zeroing).
- **It does NOT** defend against a **compromised process**: `secrets` links into the app's isolate, so a malicious/compromised dependency in the same process, a debugger, a core/memory dump, or FFI reading the heap can still reach the material. Crucially, **BIP32/39/85 run in pure Dart on a moving-GC heap that cannot be zeroized**, so the raw seed transits process RAM on every derive/sign regardless of the storage backend. Runtime confidentiality of an already-compromised device is an explicit **non-goal** — the storage backends harden the secret **at rest**, not in use.
- **Residual (in-scope, documented):** the sealed reveal widgets render words into Flutter `Text` widgets, whose `debugFillProperties` publishes `data` to DevTools in debug/profile builds; the parent widgets redact their *own* diagnostics but not the child `Text`, and the widgets do not clear their word lists on `dispose`. Both are within the debugger-inspection non-goal above (a debugger is already a compromised process) — noted so the parent redaction isn't mistaken for a defense against on-device debugging.

## Security guarantees (and honest limits)

- **Signing is intent-gated** (`IntentValidator`, issue #1703): a `signBitcoin` / `signLiquid` call carries a `SigningIntent` (the caller's authorization — outputs + max fee). A send rejects an over-cap fee, a non-wallet input, a duplicated/missing/exfiltration output; payjoin enforces the BIP78 checklist (fail-closed); a swap asserts the lockup script commits to your own derived key (the Boltz address is untrusted).
- **`trustWitnessUtxo: false`** on Bitcoin signing; FSS uses `resetOnError:false` + `AfterFirstUnlockThisDeviceOnly`; `KeychainLockedFailure` is **never** collapsed into `SecretNotFoundFailure` (locked keychain ≠ not found).
- **At rest only** is hardware-adjacent: BIP32/39/85 are pure Dart, so the secret transits the Dart heap during each derive/sign and **cannot be zeroized** (moving GC). A hardware-backed store now exists (`OublietteSecretStoreAdapter`, iOS/Android) and is wired by `init` behind the internal `SecretStorePort` seam — but it hardens the secret at rest only, not in use (see [Threat model](#threat-model--what-the-seal-is-and-is-not)).
- **Liquid signing** enforces the fee cap AND that every declared recipient **script** is present in the tx (blocking address substitution) — output scripts are not blinded. Per-output **value** and change-ownership are not provable on blinded (confidential) outputs and are a documented residual; signing fails **closed** if no output scripts can be extracted. `hasPassphrase` wallets are **rejected** for Liquid signing (LWK derives from the bare mnemonic, so it would sign under a different wallet). Liquid uses an ephemeral temp LWK db deleted after signing.
- **Swaps** carry a **caller-knowable** `SwapRequest` (amounts/invoice/direction); the package builds the commitment from the SDK-returned swap (own pubkey(s), the generated preimage's sha256, the Boltz-chosen locktime) and asserts the lockup commits to your own key — the Boltz address is untrusted. Amounts are gated per type (reverse: exact; submarine: `[invoice, maxLockup]` range; chain: exact send). `hasPassphrase` wallets are **rejected** (the boltz `SwapMasterKey` drops the passphrase). Claim/refund stay app-side via the re-derived per-swap keypair.
- **Backup vault** is **not** AEAD. The pinned third-party `recoverbull` uses AES-256-CBC + HMAC-SHA256 (**encrypt-then-MAC**, one key shared by cipher and MAC), and the surrounding JSON envelope (`createdAt`/`id`/`salt`) is unauthenticated. `encryptVault` takes the `VaultKey` as an **input** and returns only the ciphertext — the key is never co-returned, so a single call can't hand a caller both halves of the two-location model. Each backup uses a fresh `Random.secure()` IV, and tamper/wrong-key is detected via a constant-time MAC compare — so it is sound-but-not-AEAD. Hardening (HKDF enc/MAC key separation, full-envelope MAC) is an upstream `recoverbull` concern.

## Storage

Two backends behind the internal use-and-forget `SecretStorePort`: `FssSecretStoreAdapter` (over `flutter_secure_storage`) and `OublietteSecretStoreAdapter` (hardware-backed, iOS/Android only). `Secrets.init` probes device capability and wires either FSS-only or a `DualReadStore` (hardware-first read, FSS fallback + safety net; new writes go to hardware). Existing FSS seeds are copied into hardware by the one-time `Secrets.migrateToHardware()` pass; FSS removal is a later, data-driven step.

The non-secret `SecretIndexPort` (app-side Drift) is reconciled against the store at startup via `Secrets.reconcile()`: store-orphans (present in the store under the `seed_<fp>` scheme, missing from the index) are **re-indexed** (`ReconcileReport.healed`); dangling index entries, malformed keys, and any legacy-scheme keys are **surfaced, never silently dropped**.
