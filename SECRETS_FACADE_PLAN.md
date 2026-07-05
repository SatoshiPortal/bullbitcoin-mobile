# Plan — `secrets` library-style public API + terminology split + prepared migration

> **Post-audit update (2026-07-01):** shipped code diverges from this plan in a few places — treat the code as authoritative. Not built: `Slip132Format` / the `xpub(format:)` param (the barrel re-exports `primitives`' `XpubType` instead); prereq-A `RestoredVault` (`restoreVault` returns `Result<List<Fingerprint>>`). Changed: `Secrets.init` is now **async**, takes a `mode`, and returns a `SecretsInitResult` (the oubliette dual backend). Added since: `Secrets.reconcile()`/`ReconcileReport`, `migrateToHardware()`, `probeBackend()`, `KeyInvalidatedFailure`, and a hardware `OublietteSecretStoreAdapter`. The `seal_check.sh` §5 `useAndForget` allow-list is two categories (raw readers `secret_guard`+`mnemonic_reader`; store impls `oubliette_secret_store_adapter`+`dual_read_store`+`secret_migrator`), not "the handle + SecretRevealer". `example/main.dart` shipped. The internal ports still name a `Fingerprint` param `seed`/`masterSeed` — a deliberate, deferred cosmetic rename (renaming touches security-critical signing code and collides with `SecretKind.seed`/prose; not worth an unverifiable sweep).

## Context

The `secrets` package (PR #2327, branch `refactor-secrets`) is the sealed sole-owner of
user secret material. Its current public surface is **DI-shaped**: it exports 7 `*Port`
interfaces + a `SecretsLocator`, and consumers must resolve each port from `get_it`. The
package is brand-new and **nothing consumes it yet** (`grep` over `lib/` finds zero
`package:secrets` imports), so the public surface is free to change with no app-side churn.

Two problems with today's surface, raised by the maintainer:

1. **Dev experience.** A *package* is a dependency — it should feel like a library you call
   (`Secrets.importMnemonic(...)` / `Secrets.fetch(fp)`), not a DI container you wire. ARCHITECTURE.md:164/178
   already says a feature's cross-boundary surface is a concrete facade that "graduates into
   the package's exported API." Exposing ports + a locator is the deviation; a facade is the
   idiom. `get_it` is solving exactly one real problem (injecting the app's `SeedIndexPort`),
   which a one-line `init()` solves more honestly.
2. **Terminology.** The public surface conflates **mnemonic** (words) and **seed** (bytes).
   The maintainer's rule: *mnemonic = words, seed = bytes/hex; they are fundamentally
   different — a mnemonic derives a seed (PBKDF2), a seed can NEVER recover a mnemonic.* The
   names must encode that, with **Secret** as the neutral umbrella (matches the package name).

### Decisions locked with the maintainer
1. **Scope:** the package owns the **secret layer only** (root secret keyed by master
   fingerprint). The **wallet layer** (xpub/descriptors/watch-only/origin/scriptType×network)
   stays app-side in Drift `wallet_metadata`. Originless material (account xpub, watch-only
   descriptor, single keys) holds no secret → never enters the package.
2. **Handle = master `Fingerprint`.** Always present, because every in-scope secret
   (mnemonic, and the dormant hex-seed) is a BIP32 *root*. No `KeyRef`/origin handle needed.
   Corollary: a `Fingerprint` param must never be *named* `seed` (that's the conflation we're
   removing) — see Part 1.
3. **Terminology:** `Secret` (umbrella) / `Mnemonic` (words) / `Seed` (bytes). Hex-seed import
   stays a **dormant, ready seam** (mnemonic-only in practice — `createFromBytes` is never
   called in the app today), not a built path.
4. **Migration:** **prepare, do not apply.** Refactor the *package*; rewrite `ADOPTION.md` to
   the facade API; leave the app's `lib/` untouched (status stays "planning").
5. **API style:** static `Secrets` entry (create / `fetch` / registry) + a sealed `Secret`
   handle for operations; `init()` for the one injected dependency; ports become internal.

This plan changes **`packages/secrets/`** (+ its `ADOPTION.md`) and **`packages/primitives/`**
(the `Network` redesign, Part 1c). **No `lib/` app code** — the app keeps its own boolean
`Network` (`lib/core/wallet/domain/entities/wallet.dart:9`); nothing in `lib/` imports
`primitives` today, so the redesign has zero app ripple, and the app→primitives mapping is
deferred to the prepared (not applied) migration.

---

## Part 1 — Terminology split (do this first; everything else renames onto it)

Establish three words and apply them uniformly across the public surface:

- **Secret** — the stored root secret, *either kind*. The umbrella noun.
- **Mnemonic** — words (+ passphrase + language). Internal `Mnemonic` model already correct.
- **Seed** — bytes/hex (PBKDF2 output / raw entropy). Internal `Seed` model already correct.

The internal `data/models/` (`Mnemonic`, `Seed`) and the README §"Mnemonic vs Seed" already
draw this line — the bug is only that the **public ports/failures/info/params** say "Seed"
where they mean "the stored secret (a mnemonic)". Renames:

| Today | New | Why |
|---|---|---|
| `SeedInfo` | `SecretInfo` (+ `SecretKind kind`; mnemonic-only fields nullable) | indexes either kind |
| `SeedIndexPort` (app implements) | `SecretIndexPort` | indexes either kind |
| `SeedNotFoundFailure` | `SecretNotFoundFailure` | a secret, not specifically a seed |
| `DuplicateSeedFailure` | `DuplicateSecretFailure` | " |
| `NotAMnemonicSeedFailure` | `NotAMnemonicFailure` | "needs words, stored secret is a bytes seed" |
| port/param `Fingerprint seed` / `masterSeed` | internal ports keep the param, renamed `fingerprint`; **public handle methods take none** (the handle *is* the identity); the `Secrets` statics take a positional `Fingerprint` | naming a fingerprint `seed` is the conflation |
| internal `SeedPort`/`SeedAdapter` | `SecretLifecyclePort`/`SecretLifecycleAdapter` (internal) | lifecycle over secrets; hidden behind facade |

`SecretStorePort`, `SecretGuard`, `SecretStoreKeys` are already neutral — keep. Storage key
prefix stays `seed_<fingerprint>` on disk (migration-critical parity — do NOT rename the
wire key; only Dart identifiers change).

**Typed over stringly (enums when possible).** Add `MnemonicLanguage`
(`domain/value_objects/mnemonic_language.dart`) **mirroring `MnemonicLength`** — an own enum
with an `@internal asBip39` getter mapping to `bip39_mnemonic`'s `Language` (single conversion
point) + a tolerant `fromName` for the storage-decode path. Import/`fingerprintOf` take
`MnemonicLanguage`, not `String`, so `SeedAdapter`'s runtime `_lang()` lookup +
`InvalidMnemonicFailure('unknown language')` branch **disappears** (compile-safe); only the
forward-compatible storage *decode* (`Mnemonic.fromStorageBytes`) keeps a tolerant
string→enum parse (defaults english).

Files: `domain/secrets_failure.dart`, `domain/value_objects/seed_info.dart` →
`secret_info.dart`, `domain/ports/seed_index_port.dart` → `secret_index_port.dart`,
`domain/ports/seed_port.dart` → internal `secret_lifecycle_port.dart`,
`data/adapters/seed_adapter.dart`, all port method signatures, `seed_reconciler.dart`.

---

## Part 1b — Typed errors: the package defines its own `*Error` family (no raw `ArgumentError`)

Today the package throws ~13 generic `ArgumentError('...')` / `ArgumentError.value(...)`
from value-object constructors (`descriptors.dart:9,37,69`, `psbt.dart:22,45`,
`bip85_types.dart:17,28`, `backup.dart:14,37`, `ark_secret.dart:12`,
`mnemonic_length.dart:16`) plus a bare `FormatException` in `Mnemonic.fromStorageBytes:122`.
A caller can only tell them apart by string-matching the message — brittle, undiscoverable,
refactor-unsafe. Replace with a closed, self-documenting family, keeping the existing
two-axis split intact:

- **`*Failure`** (unchanged) — recoverable, RETURNED in `Result.Err`, never thrown.
- **`*Error`** — a *thrown* precondition/programmer bug (invalid value-object construction);
  crashes to Sentry. Today raw `ArgumentError`; make it typed.
- **`*Exception`** (internal, `data/datasources/`) — boundary conditions caught by
  `SecretGuard` and mapped to a `*Failure`.

New `lib/src/domain/secrets_error.dart`:
```dart
/// Thrown (never returned) precondition violations — invalid construction of a
/// value object. Programmer bugs: they crash, unlike the returned [SecretsFailure].
/// Extends [ArgumentError] (keeps invalidValue/name + existing `catch (ArgumentError)`);
/// sealed so the package's set is closed.
sealed class SecretsError extends ArgumentError { SecretsError(super.message, [super.name]); }
final class InvalidXpubError            extends SecretsError { ... }
final class InvalidDescriptorError      extends SecretsError { ... }
final class InvalidPsbtError            extends SecretsError { ... }
final class InvalidBip85PathError       extends SecretsError { ... }
final class UnknownBip85ApplicationError extends SecretsError { ... }
final class InvalidVaultKeyError        extends SecretsError { ... }
final class InvalidEncryptedVaultError  extends SecretsError { ... }
final class InvalidArkSecretError       extends SecretsError { ... }
final class UnsupportedMnemonicLengthError extends SecretsError { ... }
```

- Replace each `throw ArgumentError(...)` site with the matching typed error.
- Replace `Mnemonic.fromStorageBytes`'s `throw FormatException(...)` with a typed
  **`MalformedSecretException`** (implements `Exception`, sibling of the existing
  `SecretNotFoundException`/`KeychainLockedException` in `data/datasources/`), and switch
  `SecretGuard`'s `on FormatException` catch to `on MalformedSecretException` → still maps to
  a `*Failure` (malformed-storage stays recoverable, never a crash).
- **Export** the `SecretsError` family from the barrel (+ add `src/domain/secrets_error.dart`
  to `seal_check.sh`'s allow-list with a `show`) so callers/tests `catch`/assert specific
  types. The `*Exception`s stay internal (mapped to Failures before crossing the boundary).
- Reconcile the `secrets_failure.dart` header doc (it says "never `*Error`", meaning "don't
  model *recoverable* failures as Errors"): clarify the package DOES define typed `*Error`s
  for thrown precondition bugs, distinct from the returned `*Failure` values.

**Sibling (`primitives`) — maintainer's call.** `Fingerprint`/`Network`/`ScriptType` throw
the same raw `ArgumentError` (`fingerprint.dart:19`, `network.dart:51`,
`script_type.dart:16,30,44`). For consistency they'd get a `primitives`-side typed family
(`InvalidFingerprintError`, `UnknownNetworkError`, `UnknownScriptTypeError`). Flagged, not
assumed — the request named the secrets package.

---

## Part 1c — Redesign `primitives.Network` (kill the boolean soup)

Today `primitives/lib/src/network.dart` is a flat enum where each value carries
`isBitcoin`/`isLiquid`/`isMainnet`/`isTestnet` + `coinType` — four mutually-exclusive booleans
encoding **two orthogonal axes** (chain × environment), which permits invalid states and forces
a combinatorial blow-up for signet/regtest. Replace with the two axes made explicit:

Make the two axes explicit. **Verification finding:** every consumer of `Network` (this
package's API signatures *and* its internals — see Scope) is **per-chain**, so a unified
sealed base is unnecessary today. Two independent enums + a shared env — simpler, and it
sidesteps the `enum implements sealed class` exhaustiveness question entirely:

```dart
enum NetworkEnv { mainnet, testnet, signet, regtest }

enum BitcoinNetwork {
  mainnet(NetworkEnv.mainnet), testnet(NetworkEnv.testnet),
  signet(NetworkEnv.signet),   regtest(NetworkEnv.regtest);
  const BitcoinNetwork(this.env);
  final NetworkEnv env;
  bool get isMainnet => env == NetworkEnv.mainnet;
  int  get coinType  => isMainnet ? 0 : 1;          // SLIP-44: testnet/signet/regtest all = 1
}

enum LiquidNetwork {                                  // no signet — Liquid lacks the value
  mainnet(NetworkEnv.mainnet), testnet(NetworkEnv.testnet), regtest(NetworkEnv.regtest);
  const LiquidNetwork(this.env);
  final NetworkEnv env;
  bool get isMainnet => env == NetworkEnv.mainnet;
  int  get coinType  => isMainnet ? 1776 : 1;
}
// OPTIONAL, only if cross-chain code ever needs a unified type:
//   sealed class Network {...} + `enum BitcoinNetwork implements Network`. Dart 3 supports
//   this with exhaustive `switch`, but historically had exhaustiveness edge cases
//   (dart-lang/sdk#52456) — verify in our SDK before relying on it. Not needed now.
```

- **No invalid states** (chain is the *type*, env an enum; each chain declares only its real
  envs — `LiquidNetwork` simply has no `signet`).
- **Wrong-chain is a compile error** on per-chain methods (`bitcoinDescriptor(BitcoinNetwork)`)
  — no runtime guard, and no sealed base / exhaustiveness dependency.
- **Latent-bug fix:** select version bytes / coin type on `isMainnet`, NOT the old
  `network == Network.bitcoinTestnet` (`bip32_derivation.dart:32`) — that binary check would
  mis-handle signet/regtest (mainnet bytes for a signet key). The new `isMainnet` is correct
  for all of testnet/signet/regtest.
- **Scope:** `primitives` **plus** the secrets internals that consume `Network` today (verified
  uses, all Bitcoin-side): `key_derivation_adapter.dart` (`Network.fromEnvironment`/
  `bitcoinTestnet` → drop `fromEnvironment`; the API now passes `BitcoinNetwork`),
  `bip32_derivation.dart` (the `isMainnet` fix above), `bip85_adapter.dart` +
  `backup_vault_adapter.dart` (`Network.bitcoinMainnet` → `BitcoinNetwork.mainnet`). The liquid
  side already uses `lwk.Network` via `isTestnet`. **Zero `lib/` app ripple** (the app keeps its
  own `Network`). Update primitives tests (`fromName`/`tryFromName` → per-enum); the
  `SecretsError` primitives-sibling (Part 1b) targets the redesigned per-chain parse, not the
  old `network.dart:51`.

---

## Part 2 — The public API: `Secrets` statics + a sealed `Secret` capability handle

Two shapes. **Static `Secrets`** for wiring/creation/registry/fetch; **a sealed `Secret`
handle** (returned by `fetch`/create) carrying NON-SECRET metadata + capability methods. The
`Secret` / `MnemonicSecret` / `SeedSecret` hierarchy **is** the terminology split from Part 1
(umbrella / words / bytes), and the stored-format-bounds-possibilities lattice expressed as
types. New file `lib/src/secret.dart` (handle) + `lib/src/secrets.dart`-side statics.

```dart
abstract final class Secrets {
  static void init({required SecretIndexPort index, SecretStorePort? store});

  // create → a TYPED handle (operate immediately, no second fetch)
  static Future<Result<MnemonicSecret, SecretsFailure>> importMnemonic(
      List<String> words, {String? passphrase, MnemonicLanguage language = MnemonicLanguage.english});
  static Future<Result<MnemonicSecret, SecretsFailure>> generateMnemonic(
      {MnemonicLength length = MnemonicLength.words12});
  // no-store duplicate pre-check (returns just the handle's identity):
  static Future<Result<Fingerprint, SecretsFailure>> fingerprintOfMnemonic(
      List<String> words, {String? passphrase, MnemonicLanguage language = MnemonicLanguage.english});

  // operate on an EXISTING secret → resolves the kind from the index, returns the subtype
  static Future<Result<Secret, SecretsFailure>> fetch(Fingerprint fp);

  // registry / umbrella (cross-kind) — list returns handles (composing the index's SecretInfo)
  static Future<Result<List<Secret>, SecretsFailure>> list();
  static Future<Result<bool, SecretsFailure>>         exists(Fingerprint fp);
}
```

The handle — **metadata + capabilities; the object holds NO words/bytes** (each method does
its own `useAndForget` read internally and discards):

```dart
sealed class Secret {
  // ── non-secret metadata (from the index) — lets you call methods w/o re-passing fp ──
  Fingerprint get fingerprint;
  SecretKind  get kind;
  bool        get hasPassphrase;
  DateTime?   get createdAt;
  SecretInfo  get info;

  // ── capabilities EVERY secret-bearing kind has (read-and-forget per call) ──
  Future<Result<Xpub, SecretsFailure>>              xpub({required ScriptType scriptType, required BitcoinNetwork network, required int account, Slip132Format? format});
  Future<Result<BitcoinDescriptor, SecretsFailure>> bitcoinDescriptor({required ScriptType scriptType, required BitcoinNetwork network});
  Future<Result<LiquidDescriptor, SecretsFailure>>  liquidDescriptor({required LiquidNetwork network});
  Future<Result<SignedPsbt, SecretsFailure>>        signBitcoin({required Psbt psbt, required SigningIntent intent, required ScriptType scriptType, required BitcoinNetwork network});
  Future<Result<SignedPsbt, SecretsFailure>>        signLiquid({required Psbt pset, required SigningIntent intent, required LiquidNetwork network});
  Future<Result<CreatedSwap, SecretsFailure>>       createBtcReverse({required int index, required SwapIntent intent, /* …urls, amounts… */});  // +4 swap methods
  Future<Result<({EncryptedVault vault, VaultKey vaultKey}), SecretsFailure>> encryptVault({String? derivationPath});
  Future<Result<Bip85Derivation, SecretsFailure>>   bip85ChildMnemonic({required MnemonicLength length, required int index});
  // … bip85 bip39Child / hex / recoverbullKey / ark …
  Future<Result<void, SecretsFailure>> delete();
  // NOTE: NO reveal()/widget methods here — display is the dedicated SecretRevealer
  // widget (below). The handle returns data; UI is rendered by one sealed widget.
}

// Subtypes are metadata-carriers (+ the future signing-capability split). Display is NOT a
// handle method — it lives in SecretRevealer.
final class MnemonicSecret extends Secret {
  int    get wordCount;
  String get language;
}

final class SeedSecret extends Secret {            // DORMANT — no import path built yet
  int get byteLength;
}

// FUTURE, secret-bearing, signable — DESIGNED-FOR, NOT BUILT:
// final class DescriptorSecret extends Secret { /* a private (xprv) descriptor */ }
```

Usage — metadata on hand, no fingerprint re-passing, capability checked by the compiler:

```dart
final res = await Secrets.fetch(fp);
if (res case Ok(value: final secret)) {
  final d = await secret.bitcoinDescriptor(scriptType: ScriptType.bip84, network: BitcoinNetwork.mainnet);
  if (secret case MnemonicSecret m) {
    print('${m.wordCount} words · ${m.language}');         // metadata (needs narrowing), no secret
  }
  return SecretRevealer(secret: secret, strings: strings);  // display (any kind), sealed widget
}
```

Design notes:
- **Signing/derivation/bip85/vault live on the BASE** — every secret-bearing kind can do
  them, and there is no watch-only `Secret` in scope to exclude (decision #1). The only
  subtype-specific capability today is **mnemonic word-reveal**. A `SecretSigner` marker
  interface is **held in reserve** (a future private `DescriptorSecret` also signs, so no
  split is needed yet) — add it only if a non-signing secret-bearing kind ever appears.
- The handle holds only `fingerprint + kind + metadata`. **No `.words`/`.bytes`/`.hex`
  getter**; display is via `SecretRevealer` (sealed widget), never returned data.
  `seal_check.sh`'s `useAndForget` allow-list gains the handle + `SecretRevealer` read paths;
  the lifetime guarantee is preserved.
- **Capability-as-type, honestly scoped:** with display moved to `SecretRevealer` and
  signing/derivation on the base, the *only* subtype-specific public surface today is metadata
  getters (`wordCount`/`language` on `MnemonicSecret`, `byteLength` on `SeedSecret`). The sealed
  hierarchy still earns its place — `SecretRevealer`'s exhaustive `switch`, typed metadata,
  and the reserved `SecretSigner`/future `DescriptorSecret` split — but the headline
  "compiler blocks `reveal()` on a seed" guarantee is now internal to `SecretRevealer`, not a
  public-API affordance. (Alternative considered: a flat `Secret{kind, wordCount?, …}` + enum
  switch; rejected — the sealed types read better and the maintainer wants `is MnemonicSecret`.)
- `xpub` gains `format:` — a **new** `Slip132Format` enum (xpub/ypub/zpub), mirroring the app's
  `XpubType`; wraps the existing `convertXpub`; default = canonical for scriptType+network.
- **Capability nuance for when `SeedSecret` lands:** `encryptVault` is likely **mnemonic-only**
  — the recoverbull envelope backs up the parent's *words* (prereq A: `mnemonic` as
  `List<String>`), which a bytes-`SeedSecret` doesn't have; it would move to `MnemonicSecret`.
  All `bip85*` (incl. `bip85ChildMnemonic`) derive from the BIP32 **root**, which a `SeedSecret`
  also has → they **stay on the base**. Today everything is a mnemonic so the placement is
  harmless; revisit `encryptVault` at seed-import.
- `masterFingerprint` (the homeless `KeyDerivationPort` method) is **dropped** — the handle
  already *is* the fingerprint.
- `SecretInfo` is the `SecretIndexPort` data contract (app-implemented); `Secret` **composes**
  one and delegates its getters (no field duplication), exposing the raw record via `.info`.
  Consumers see only `Secret` (incl. from `list()`); `SecretInfo` surfaces only when
  implementing the index. Swap methods (5) may move to a `SwapCreator` mixin — impl detail.
- Internally each handle method delegates to the same internal adapters
  (`SignerAdapter`/`KeyDerivationAdapter`/…) via `_wiring`; the ports stay internal (Part 5).

### Sealed display: one `SecretRevealer` widget (not per-handle methods)

Display is a single polymorphic sealed widget, not a method on the handle:

```dart
class SecretRevealer extends StatefulWidget {   // STATEFUL — async read + refetch-on-change
  const SecretRevealer({required this.secret, required this.strings});
  final Secret secret;                 // any kind — the widget does ALL conditional rendering
  final SecretRevealerStrings strings; // localized labels only (package can't localize)
  // _State: load ONCE in initState (FutureBuilder), refetch on didUpdateWidget when
  //   widget.secret changes (mirrors today's MnemonicView stale-seed fix) — NOT per build,
  //   to minimize secret heap-lifetime. build(): switch (secret) {
  //     MnemonicSecret() => words grid, + passphrase row IFF one is stored,
  //     SeedSecret()     => hex,
  //   } + unavailable/locked states. Every branch PrivacyGuard-wrapped; reads via _wiring
  //   (use-and-forget). Passphrase presence drives rendering — no flag.
}
```

- **Why a widget over a handle method:** the handle returns *data*; UI is rendered by one
  sealed widget. Displaying is polymorphic-by-nature ("show whatever this secret naturally
  is"), so the runtime `switch` is correct — there's no illegal call to block. The
  compile-time capability that matters (signing) stays on the handle, unaffected.
- **Self-sourcing:** `SecretRevealer` pulls the internal `MnemonicReader` from `Secrets`'s
  `_wiring` (no GetIt, no injection); `StateError` if `init()` wasn't called.
- **Seal:** the `SeedSecret` branch *is* the on-screen hex view (`PrivacyGuard`-wrapped, never
  a returned `String`). `MnemonicView`/`SeedHexView` **collapse into `SecretRevealer`'s
  branches** and are no longer separately exported → the public widget surface shrinks.
- **Out of scope for the revealer:** `VerifyBackupView` (a re-entry/confirmation flow, not
  display — kept; may later become a parallel `BackupVerifier(secret)`) and
  `Bip85MnemonicView`/`Bip85HexView` (render *derived* `Bip85*` payloads, not a stored
  `Secret`).

---

## Part 3 — Remove `get_it` from the package; self-wire via `init()`

`get_it` currently appears in `lib/locator.dart` **and** in two sealed widgets
(`mnemonic_view.dart:71`, `verify_backup_view.dart`) which resolve `MnemonicReader` from
`GetIt.instance`. Replace all three:

- **`init()`** builds the internal graph once (lazy), replacing everything `SecretsLocator`
  did. Only external input = the app's `SecretIndexPort`. Optional `store` override defaults to
  `FssSecretStoreAdapter(FlutterSecureStorageAdapter.standard())` — it's both the **test seam**
  and the **future hardware-backend seam** (the README's "oubliette" `SecretStorePort` drops in
  here). Honest note: `_wiring` is still a process-global initialized by `init()` (a
  cleaner-faced service locator, not its elimination) — the win is DX + a tighter surface, the
  cost is init-ordering, guarded by a `StateError('Secrets.init() must be called before use.')`
  + `@visibleForTesting Secrets.reset()` for test isolation. (`store` is internal-typed, so
  app-facing *backend selection* — if ever needed — would require a small public shape later.)
- **Widgets:** `SecretRevealer` and `VerifyBackupView` read the internal `MnemonicReader`
  directly from `Secrets._wiring` (no GetIt, no injection). The
  `?? GetIt.instance<MnemonicReader>()` fallback + its surrounding try/catch
  (`mnemonic_view.dart:71` / `_load()`) are **removed**; `StateError` from an un-`init()`-ed
  `_wiring` replaces the old "locator never called" catch. (`MnemonicView`/`SeedHexView`
  collapse into `SecretRevealer`'s branches — Part 2.)
- **Delete** `lib/locator.dart`; **remove** `get_it` from `pubspec.yaml` dependencies.

Internal `_Wiring` builds one `SecretStorePort`, the `MnemonicReader`, and the six adapters
(`SecretLifecycleAdapter`, `KeyDerivationAdapter`, `SignerAdapter`, `SwapSignerAdapter`,
`BackupVaultAdapter`, `Bip85Adapter`) — the same graph `registerRepositories` built. The
`Secrets` statics and the `Secret` handle resolve `_wiring` **lazily per call** (a getter), so
static-field initializers never touch `_wiring` before `init()`. (Confirmed lint-clean: the package's
`analysis_options.yaml` already disables `avoid_classes_with_only_static_members`, so a
static facade is sanctioned by design.)

---

## Part 4 — Barrel + seal-check

- **`lib/secrets.dart`** exports only: `Secrets`; the handle hierarchy
  `Secret`/`MnemonicSecret`/`SeedSecret` + `SecretKind`; the `SecretsFailure` family (renamed)
  + the `SecretsError` family (Part 1b); value objects (`SecretInfo`, `MnemonicLength`,
  `MnemonicLanguage`,
  `Xpub`/`BitcoinDescriptor`/`LiquidDescriptor`, `Slip132Format`, `Psbt`/`SignedPsbt`,
  `SigningIntent` family, `CreatedSwap`, `VaultKey`/`EncryptedVault`, `Bip85*`, `ArkSecret`,
  `SecretRevealerStrings`); the sealed widgets (`SecretRevealer`, `VerifyBackupView`,
  `Bip85MnemonicView`, `Bip85HexView`); `SecretIndexPort` (the app implements it). **No more**
  `*Port` (other than `SecretIndexPort`), **no `SecretsLocator`**, and `MnemonicView`/
  `SeedHexView` are now internal (folded into `SecretRevealer`).
- **Re-export the `primitives` types used in the public signatures** (`Fingerprint`,
  `BitcoinNetwork`/`LiquidNetwork`/`NetworkEnv`, `ScriptType`, `Result`/`Ok`/`Err`)
  so a consumer needs a single `import 'package:secrets/secrets.dart';` — true library feel.
- **`tool/seal_check.sh`** is a **default-deny allow-list** of exact barrel export paths
  (`public_exports`, lines 33-53) — adding/removing an export FAILS until the list matches.
  Edit it: **drop** the 6 hidden ports (`seed_port`, `key_derivation_port`, `signer_port`,
  `swap_signer_port`, `backup_vault_port`, `bip85_port`); **rename**
  `seed_info.dart`→`secret_info.dart` and `seed_index_port.dart`→`secret_index_port.dart`;
  **add** the new public paths (`src/secrets.dart` statics + `src/secret.dart` handle +
  `src/domain/secrets_error.dart` + `src/ui/widgets/secret_revealer.dart`, each with a `show`);
  **drop** `src/ui/widgets/mnemonic_view.dart` (now internal, folded into `SecretRevealer`).
  Also remove the barrel's
  `export 'locator.dart' show SecretsLocator;` line (non-`src` export → no allow-list entry,
  just delete from `secrets.dart`). Check 1 (external `src/` import), 3/3b (internal-member
  lint), 4 (`*Impl`) are unaffected. **Check 5 (`useAndForget` allow-list)** gains the handle's
  read path (`secret.dart`) alongside `secret_guard.dart`+`mnemonic_reader.dart`. **Check 6
  (FSS confinement)** is unaffected (the default `init()` store is built inside the
  already-allow-listed adapter).
- **`test/barrel_seal_test.dart`**: replace the `expect(SeedPort, …)`/`SecretsLocator`
  references with `expect(Secrets, isNotNull)` + `expect(MnemonicSecret, isNotNull)` + the
  renamed failures/errors; assert the removed ports are NOT referenceable (compile-time, by
  not importing them).
- **Rewrite `packages/secrets/README.md`** — it still documents the *port* surface (the
  `| Port | Returns |` table, `SeedPort`, `SecretsLocator.registerDatasources`). Re-document the
  `Secrets`/`Secret`/`SecretRevealer` library API + `Secrets.init(...)`. Add thorough `///`
  dartdoc on the public surface (it's the only docs a consumer sees). This is front-door DX, not
  optional cleanup.

---

## Part 5 — Internal layering is preserved

The `data/` adapters, `domain/` ports (now internal), `crypto/` derivation, and value
objects **stay** — only their *exposure* changes. The facade delegates to the same ports;
the ports delegate to the same adapters. Adapter/crypto unit tests
(`test/{crypto,data,domain,migration}/…`) keep constructing concrete adapters against
`FakeSecureKeyValueStore` and are largely unaffected (only renamed identifiers + the
`seed:`→positional param change ripple). This keeps the security-critical logic test
coverage intact.

---

## Part 6 — Prepared migration (rewrite `ADOPTION.md`, apply nothing in `lib/`)

`ADOPTION.md` is the existing migration spec, written against the **port** API. Rewrite its
call-site references to the **facade** API; the structure (prerequisites A/B/C, phases 0–7)
stays valid. No app `lib/` files change — status remains "planning".

Key reconciliations:
- **Phase 0 wiring:** `SecretsLocator.registerDatasources/registerRepositories` + "register
  `SeedIndexPort` first" → **`Secrets.init(index: DriftSecretIndex())`** (single call; the
  app builds the Drift-backed `SecretIndexPort`). The "locator throws if index missing"
  becomes "`init` requires `index`".
- **Rename ripple in the doc:** `SeedPort.importMnemonic` → `Secrets.importMnemonic`;
  `KeyDerivationPort.accountXpub` → `(await Secrets.fetch(fp)).xpub(...)`; `bitcoinDescriptor`
  → `secret.bitcoinDescriptor(...)`; `SignerPort.signBitcoinPsbt` → `secret.signBitcoin(...)`;
  swap/vault/bip85 → handle methods likewise; `SeedInfo`→`SecretInfo`,
  `SeedIndexPort`→`SecretIndexPort`, `SeedNotFoundFailure`→`SecretNotFoundFailure`.
- **Unchanged migration-safety facts (the load-bearing ones):** on-disk `seed_<fingerprint>`
  scheme + value format already match (migration 005); fingerprint derivation byte-identical;
  `Mnemonic.fromStorageBytes` reads all legacy formats; reads bypass the index → an
  existing-but-unindexed seed is never "missing". **No seed-data migration, no fund-loss.**
- **Package-contract prerequisites A/B/C** (legacy backup envelope w/ `path`; constructible
  `SwapIntent`/typed swap requests; payjoin-aware extraction) are **package-side** and remain
  in scope of the package refactor — keep them in the doc as package work, not app work.
- The hex-seed (`Seed` bytes) path stays dormant per decision #3 — the doc notes the seam
  exists, not built.

---

## Execution order & new public types

**Order (each ≈ one atomic conventional commit, AGENTS.md):**
1. **primitives:** `Network` redesign (Part 1c) + tests.
2. **secrets terminology rename** (Part 1) — `Seed*`→`Secret*`/`Mnemonic*`, `MnemonicLanguage`,
   param `seed`→`fingerprint`; internal-only, no behavior change.
3. **typed errors** (Part 1b) — `SecretsError` family + `MalformedSecretException`.
4. **`Secret` handle + `Secrets` statics** (Part 2) — delegating to the (still-internal) ports;
   adapters map chain-typed `Network`.
5. **`SecretRevealer`** — fold in `MnemonicView`/`SeedHexView`.
6. **get_it removal + `init()`** (Part 3) — delete `locator.dart`.
7. **barrel + `seal_check.sh` + `barrel_seal_test`** (Part 4).
8. **docs:** README rewrite + dartdoc + `example/`.
9. **`ADOPTION.md` rewrite** (Part 6) — prepared, not applied.

**New public types introduced** (for the barrel + dartdoc): `Secret` / `MnemonicSecret` /
`SeedSecret`, `SecretKind`, the `SecretsError` family, `MnemonicLanguage`, `Slip132Format`,
`SecretRevealerStrings`, `SecretRevealer`; renamed `SecretInfo`/`SecretIndexPort`/`Secret*Failure`;
re-exported `BitcoinNetwork`/`LiquidNetwork`/`NetworkEnv`. Internal-only:
`MalformedSecretException`, `SecretLifecyclePort`/`Adapter`, `MnemonicView`/`SeedHexView`.

**DX nicety (primitives `Result`):** it has `fold`/`map`/`mapErr` but no `valueOrNull`/
`getOrElse`. For a Result-on-every-call API, add those two to `primitives` — they cut a lot of
`case Ok/Err` boilerplate at app call sites. Small, optional, high leverage.

---

## Verification

- `cd packages/primitives && flutter analyze && flutter test` — the redesigned `Network`
  (Part 1c: two chain enums + `NetworkEnv`, no sealed base) compiles, and the rewritten network
  tests (`fromName`/`tryFromName` → per-enum, `coinType`/`isMainnet`) pass. (If the optional
  sealed base is ever added, that's where the `enum implements sealed class` exhaustive-`switch`
  check applies — not needed now.)
- `cd packages/secrets && flutter analyze` clean under `--fatal-infos` (the seal relies on
  `implementation_imports` being fatal).
- `flutter test` green — adapter/crypto/migration suites (renamed identifiers + chain-typed
  `Network` mapping) + **new** unit tests for the `Secrets` statics, the `Secret` handle
  (fetch/list wrapping, per-kind narrowing), and `SecretRevealer` + the rewritten
  `barrel_seal_test.dart`.
- `make seal-check` passes with the new barrel (no stray `src/` exports; FSS confined).
- **Ship `packages/secrets/example/main.dart`** (idiomatic pub DX; doubles as the smoke test):
  a single `import 'package:secrets/secrets.dart';` + `Secrets.init(index: _FakeIndex())` +
  round-trip `Secrets.importMnemonic(...)` → `Secrets.fetch(fp)` → `secret.bitcoinDescriptor(...)`
  + `SecretRevealer(secret: secret, …)`, asserting no `primitives`/`get_it`/`src/` import is
  needed by the consumer, and that `secret.wordCount` does **not** compile on a bare `Secret`
  (it requires narrowing to `MnemonicSecret`).
- **On-device / integration test for the signing ownership path** (`wallet.isMine` after the
  `Network`→bdk mapping change). Host `flutter test` can't load native BDK, so the riskiest path
  (owned-change recognition — the PR's original lookahead finding) needs a device/integration
  test, not just unit coverage of the pure `IntentValidator`.
- Confirm `grep -rn "get_it\|GetIt" packages/secrets/lib` returns nothing.
- Confirm `grep -rnE "throw (ArgumentError|FormatException)\b" packages/secrets/lib` returns
  nothing (all replaced by the typed `SecretsError` family / `MalformedSecretException`).
- App `lib/` diff is empty (migration prepared, not applied) — `ADOPTION.md` is the only
  non-package file touched.

## Appendix A — Full signatures (for design review)

Statics on `Secrets` (create/fetch/registry); operations live on the `Secret` handle. All
async ops return `Future<Result<T, SecretsFailure>>`. `BitcoinNetwork`/`LiquidNetwork`/
`NetworkEnv`, `ScriptType`, `Fingerprint`, `Result` come from `primitives` (re-exported by the
barrel). Handle operations need **no
`fingerprint` argument** — the handle already carries it.

```dart
abstract final class Secrets {
  static void init({required SecretIndexPort index, SecretStorePort? store});
  @visibleForTesting static void reset();

  // create → a TYPED handle
  static Future<Result<MnemonicSecret, SecretsFailure>> importMnemonic(
    List<String> words, { String? passphrase, MnemonicLanguage language = MnemonicLanguage.english });
  static Future<Result<MnemonicSecret, SecretsFailure>> generateMnemonic(
    { MnemonicLength length = MnemonicLength.words12 });
  // dormant (decision #3): importSeed(Uint8List) -> SeedSecret — NOT built yet.

  // no-store duplicate pre-check
  static Future<Result<Fingerprint, SecretsFailure>> fingerprintOfMnemonic(
    List<String> words, { String? passphrase, MnemonicLanguage language = MnemonicLanguage.english });

  // operate on an existing secret → resolves kind from the index, returns the subtype
  static Future<Result<Secret, SecretsFailure>> fetch(Fingerprint fp);

  // registry / umbrella — list returns handles (each composing the index's SecretInfo)
  static Future<Result<List<Secret>, SecretsFailure>> list();
  static Future<Result<bool,         SecretsFailure>> exists(Fingerprint fp);
}

sealed class Secret {
  Fingerprint get fingerprint;
  SecretKind  get kind;
  bool        get hasPassphrase;
  DateTime?   get createdAt;
  SecretInfo  get info;

  // chain-typed networks (Part 1c): wrong-chain is a COMPILE error — no runtime guard.
  Future<Result<Xpub, SecretsFailure>> xpub({
    required ScriptType scriptType, required BitcoinNetwork network, required int account,
    Slip132Format? format /* xpub/ypub/zpub; default = canonical for scriptType+net */ });
  Future<Result<BitcoinDescriptor, SecretsFailure>> bitcoinDescriptor({
    required ScriptType scriptType, required BitcoinNetwork network });
  Future<Result<LiquidDescriptor, SecretsFailure>> liquidDescriptor({ required LiquidNetwork network });

  Future<Result<SignedPsbt, SecretsFailure>> signBitcoin({
    required Psbt psbt, required SigningIntent intent,
    required ScriptType scriptType, required BitcoinNetwork network });
  Future<Result<SignedPsbt, SecretsFailure>> signLiquid({
    required Psbt pset, required SigningIntent intent, required LiquidNetwork network });

  // swaps (commitment-asserted). NOTE: ADOPTION prereq B replaces `SwapIntent` with typed
  // per-type requests — these simplify accordingly; consider a SwapEndpoints/SwapContext bundle.
  Future<Result<CreatedSwap, SecretsFailure>> createBtcReverse({
    required int index, required SwapIntent intent, required int outAmountSat,
    required String electrumUrl, required String boltzUrl, required BitcoinNetwork network, String? outAddress });
  Future<Result<CreatedSwap, SecretsFailure>> createBtcSubmarine({/* index, intent, invoice, urls, BitcoinNetwork */});
  Future<Result<CreatedSwap, SecretsFailure>> createLbtcReverse({/* …as btc reverse, LiquidNetwork… */});
  Future<Result<CreatedSwap, SecretsFailure>> createLbtcSubmarine({/* …as btc submarine, LiquidNetwork… */});
  Future<Result<CreatedSwap, SecretsFailure>> createChainSwap({  // cross-chain → NetworkEnv
    required int index, required SwapIntent intent, required int amountSat,
    required String btcElectrumUrl, required String lbtcElectrumUrl,
    required String boltzUrl, required NetworkEnv env, required ChainDirection direction });

  // backup vault. prereq A adds `derivationPath` + returns a RestoredVault.
  Future<Result<({EncryptedVault vault, VaultKey vaultKey}), SecretsFailure>> encryptVault({ String? derivationPath });

  Future<Result<Bip85Derivation, SecretsFailure>> bip85ChildMnemonic({ required MnemonicLength length, required int index });
  Future<Result<Bip85Derivation, SecretsFailure>> bip85Bip39Child({ required Bip85Application app, required int index, required MnemonicLength length });
  Future<Result<Bip85HexResult, SecretsFailure>>  bip85Hex({ required int numBytes, required int index });
  Future<Result<VaultKey, SecretsFailure>>        bip85RecoverbullKey({ required Bip85Path path });
  Future<Result<ArkSecret, SecretsFailure>>       bip85Ark();

  Future<Result<void, SecretsFailure>> delete();
}

final class MnemonicSecret extends Secret { int get wordCount; String get language; }
final class SeedSecret     extends Secret { int get byteLength; }   // DORMANT
// FUTURE: final class DescriptorSecret extends Secret { } // private (xprv) descriptor — NOT built

// display: ONE polymorphic sealed widget (Part 2) — not a handle method; STATEFUL (read once)
class SecretRevealer extends StatefulWidget {  // does ALL conditional rendering from `secret`
  const SecretRevealer({ required Secret secret, required SecretRevealerStrings strings });
}
// restore (no handle — there's nothing to fetch yet):
//   static Future<Result<List<Fingerprint>, SecretsFailure>> Secrets.restoreVault({EncryptedVault, VaultKey});  // prereq A: -> RestoredVault
```

### Design concerns to weigh (review targets)
1. **`Network`: RESOLVED → redesigned (Part 1c).** Two chain enums `BitcoinNetwork`/
   `LiquidNetwork` + `NetworkEnv` (no sealed base — all consumers are per-chain); methods take
   the chain type → wrong-chain is a **compile error** (no runtime guard, no exhaustiveness
   dependency). `createChainSwap` takes `NetworkEnv`.
2. **`language`: RESOLVED → `MnemonicLanguage` enum** (mirrors `MnemonicLength.asBip39`); the
   runtime "unknown language" failure becomes compile-impossible (Part 1).
3. **`SecretRevealer` runtime-switches** on the secret kind (display is polymorphic-by-nature);
   the compile-time capability that matters (signing) stays on the handle. Confirm intended.
4. **`SigningIntent` on `signBitcoin/signLiquid`** is the caller's authorization (outputs +
   maxFee). Prereq C makes payjoin extraction work; the intent stays the gate. OK as designed.
5. **Swap arity is high** (urls, index, network/env per call). Prereq B's typed requests + a
   `SwapEndpoints`/`SwapContext` bundle shrink this across the 5 methods.
6. **`restoreVault` is a static, not a handle method** — it ingests an external vault and
   *produces* fingerprints, so there's no pre-existing handle to hang it on. Confirm placement
   (`Secrets.restoreVault(...)`).
7. **Swap/derivation/bip85 on the base `Secret`** (every secret-bearing kind can do them) vs a
   future `SecretSigner` interface — held in reserve until a non-signing kind exists.

## Resolved decisions (cumulative)
- **`fetch` = pure get from the index.** `Secrets.fetch(fp)` reads the **index** (non-secret:
  fingerprint + kind + metadata), builds the typed handle, and returns
  `Err(SecretNotFoundFailure)` if absent (the return is `Result<Secret>`, not nullable) — it
  **never touches the secret store**. Raw-secret reads happen only inside the
  handle's *methods* (use-and-forget) and inside `restoreVault`. Verb model: `fetch` = get,
  `importMnemonic`/`generateMnemonic`/`restoreVault` = add. Orphans (in store, not in index)
  are healed by the **existing startup reconcile**, which runs before any `fetch`; no
  store-probe fallback needed.
- **`SecretKind` = `mnemonic` + `seed`** (both values; only `mnemonic` reachable until the seed
  import path lands).
- **Redesign `primitives.Network`** (Part 1c) into two chain enums `BitcoinNetwork`/
  `LiquidNetwork` + a shared `NetworkEnv` (mainnet/testnet/signet/regtest) — replacing the
  boolean soup and supporting signet/regtest. **No sealed base** (verified: every consumer is
  per-chain), which sidesteps the `enum implements sealed class` exhaustiveness question. Methods
  take `BitcoinNetwork`/`LiquidNetwork` → **wrong-chain is a compile error**; `createChainSwap`
  takes `NetworkEnv`. Zero app ripple (`lib/` doesn't import `primitives`).
- **`restoreVault` = a static create/add op.** It decrypts the vault in-package, **writes** the
  recovered seed(s) to the store, and returns their fingerprints (`RestoredVault` per prereq A
  = fingerprints + non-secret envelope metadata). Static (no pre-existing handle) — a mirror of
  `importMnemonic`, sourced from a vault.
- **`SecretInfo` vs `Secret` — different layers, not duplicates.** `SecretInfo` is the
  **pure-data contract of `SecretIndexPort`** (the **app**-implemented Drift index returns it;
  the app can't build a `Secret`, which needs the package's `_wiring`). `Secret` is the
  operational handle = it **composes a `SecretInfo`** (delegates `fingerprint`/`kind`/`wordCount`,
  no copied fields) and adds the capability methods. Consumer-facing, **`list()` returns
  `List<Secret>`** (handles) so the only type you see is `Secret`; `SecretInfo` is named only
  by code *implementing* `SecretIndexPort`.
- **`primitives` re-export = curated `show`** (`Fingerprint`/`ScriptType`/`Result` +
  `BitcoinNetwork`/`LiquidNetwork`/`NetworkEnv`), mirroring `bull_ui`.
- **Names: `Secrets` (API/statics) + `Secret` (handle).** The one-letter plural/singular
  difference is accepted (idiomatic collection-vs-element; autocomplete disambiguates) — no
  `SecretsFacade`.
- **`SecretRevealer` does all conditional rendering.** The consumer passes *only* the `Secret`;
  the widget switches on its content and renders every case itself — mnemonic with passphrase,
  mnemonic without, seed hex, plus the unavailable/locked states. The single extra input is
  `SecretRevealerStrings` = the *localized UI labels* the package can't translate (e.g. "phrase
  unavailable", "no recovery phrase"); it is **not** the passphrase (that value comes from
  storage with the words). No `showPassphrase` toggle needed — presence of a passphrase drives
  the rendering.

## Still open
- **One-shot ergonomics** (accepted) — the handle costs two awaits for a single op; add thin
  static shortcuts only if hot call sites feel heavy.
