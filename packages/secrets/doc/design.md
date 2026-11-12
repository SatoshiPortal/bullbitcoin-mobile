# secrets — design notes

What the package promises, how it is built and how to audit it. The [README](../README.md) is the short version: lifecycle, per-secret operations and generated public call trees.

## The contract

**The lifecycle and secret handles carry no key material.** `Secrets` creates, imports, fetches, lists and deletes stored secrets. `Secret` holds a fingerprint, a metadata snapshot and access to operations on that entry. Each operation reads its material when needed; a handle is not a cached seed and does not guarantee future storage access.

The grouped interface is the only public spelling: `secret.derive.xpub`, `secret.derive.descriptors.bitcoin`, `secret.sign.psbt`, `secret.backup.recoverbull`, `secret.verify.mnemonic` and `secret.widgets.mnemonicView`. Extension types forward directly to internal implementation methods on `Secret`. Those flat methods remain together for audit, but their `@internal` annotations exclude them from the consumer API. The forwarding invariant prevents the groups from implementing additional behavior or handling material themselves.

`secrets.preview` is the one operation on words that are not stored. `bitcoinDescriptors` derives one seed from the candidate words in their own BIP39 language and with their passphrase, off the keystore and in a separate isolate, and returns only the public descriptors of each requested script type; it creates no handle, because a handle that held unstored words would be the cached material handles never are. The isolate zeroes the seed buffer before returning; copies inside bip32_keys, bdk and the master xprv string are immutable or library-internal, so their erasure cannot be guaranteed. The material it builds is seed-only, so no word-based library can run on it. The descriptors equal those of an import of the same words in the same language, since `import` and `contains` take the same `language` parameter. The wallet package scans with those descriptors before import and never receives the words.

`import` returns a `Secret` on success and a dedicated duplicate failure for an existing entry. An import never silently overwrites a stored secret. `contains(words:, language:, passphrase:)` combines candidate validation and a preliminary existence check; `exists(id)` checks a known fingerprint. Neither replaces the import's own duplicate decision. `idOf` is not public.

`list` returns `List<SecretEntry>`. The sealed family has two alternatives: `Secret` for a usable entry and `UnreadableSecret` carrying the failure and a fingerprint when recoverable. This preserves individual unreadable entries without making a usable handle's properties nullable. A global read failure returns an `Err`, not an empty list.

`verify.mnemonic(words)` compares stored words alone and requires a mnemonic entry. `verify.seed(hex)` compares the full seed bytes, derived with the stored passphrase for mnemonic entries and read directly for seed-only entries. A mismatch is `Ok(false)`; inability to perform the comparison is a failure. No stored material leaves either method.

The identifier is `primitives.Fingerprint`: eight lowercase hex characters validated at construction. Networks, script types, xpub formats, `Result` and `Failure` come from `primitives` too. Applications import that canonical vocabulary rather than a duplicate set of types.

## Generated public API map

The README's simplified `Secrets` and `Secret` call trees are generated from `lib/secrets.dart` by `tool/api_docs.dart`. It resolves the canonical export namespace, exported extensions and extension types with the installed analyzer. Public instance members are included; private or `@internal` members, constructors, static members and Object protocol methods are omitted. Future Result returns are reduced to their success type with a shared legend. Required and optional arguments and explicit defaults come from the resolved elements.

Synchronous getters and factories returning exported capability objects are expanded. Extension types are capability candidates; ordinary classes must have callable members, no public constructor and no external superclass other than Object. Data objects, asynchronous results and framework widgets remain leaves. Traversal stops at a repeated type. This is a navigation map, not a replacement for dartdoc: parameter types, constructor setup and behavior are explained in the surrounding documentation.

Run `make secrets-api-docs` after changing the public API and include the README update in the same change. `make secrets-api-docs-check` is nonmutating and fails on drift in both `make checks` and CI. No operation names are duplicated in generator configuration; only the two root types are configured. Synthetic resolved-source tests cover exports, nested groups, defaults, internal-member exclusion and stale-document detection. Behavioral prose remains authored and reviewed separately.

## Passphrase

Account xpub derivation, Bitcoin signing, Liquid descriptors and signatures, BIP85 and the swap key honour a BIP39 passphrase. Every existing Liquid wallet is a passphrase-less default, so its keys are those lwk's word-based signer derived. A RecoverBull vault contains the words and a `mnemonicLanguage` field (including English), without the passphrase; its encryption key derives from the original secret, including its passphrase.

These methods return their values directly. There is no passphrase wrapper: the behavior is part of each operation's contract. One operation refuses instead: `silentPayments.account`, because bwk derives from the words alone (`SpAccount.createFromMnemonic`, `mnemonic.to_seed("")`) and the account would be the passphrase-less sibling's — `PassphraseUnsupportedFailure`. `secrets.recoverbull.restore(vault:, key:, passphrase:)` accepts the passphrase separately; the vault cannot verify whether the supplied passphrase is correct. Without one, it restores the passphrase-less wallet.

**Default wallets never have a passphrase.** The app generates or imports their words without one. A restored `Secret` handle is also rejected by `CreateDefaultWalletsUsecase` if it carries a passphrase, before any wallet is created. Liquid, RecoverBull recovery, BIP85, swaps, Silent Payments and the physical backup check rely on this invariant. Passphrase-protected Bitcoin wallets are imported non-default wallets.

The bound lwk and Boltz APIs accept the full BIP39 seed, including the passphrase (`SwSigner::from_seed_with_network` for Liquid). An empty passphrase produces the same seed as the previous word-based signer's `mnemonic.to_seed("")`, preserving its keys for identical input. A non-empty passphrase deliberately derives a different wallet. Device vectors compare exact Liquid descriptors as well as the passphrase-separated results.

## BIP39 language

The language is an explicit import/preview parameter and stored metadata, not inferred from words. Stored mnemonic JSON has an optional `language` key, written only for non-English. Its value is bip39's `Language.label` (`english`, `japanese`, `korean`, `spanish`, `chinese-simplified`, `chinese-traditional`, `french`, `italian`, `czech`, `portuguese`), never the bip39 package's Dart identifiers; a golden test pins all ten in both directions, so a label change in bip39 fails the suite before it changes bytes on devices. Absent means English; an explicit null or unknown value fails parsing. English JSON remains byte-identical. Raw seed entries have no language. The domain references only the existing pure-Dart `Language` enum, guarded by the import invariant, rather than duplicating that vocabulary.

`FingerprintDeriver.seed` is the single PBKDF2 implementation used by preview, import, duplicate checks, verification and all seed-based operations. Words normalize to NFKD before storage and verification. ⚠️ Japanese and Korean words are therefore stored decomposed (kana with voiced marks and Hangul syllables become several code points); any consumer that compares or displays them must normalise its own input to NFKD first, and NFC for display if it needs composed text. Passphrases retain their historical stored representation and normalize during seed computation. Full seed comparison handles differing word spellings, language or passphrase; invalid existing material stays occupied and cannot be overwritten.

Bitcoin signing parses the Dart-derived master xprv with BDK, never the words. The key-material gate audits that signer location specifically, allowing only xprv parsing and disposal there. Liquid and Boltz receive the full BIP39 seed, passphrase included, through lwk's and boltz's seed APIs, never the words. BWK still requires English words, and a non-English Silent Payments account returns `LanguageUnsupportedFailure`. This stage does not change the UI or English generation.

Every new RecoverBull vault records its wordlist in the reserved `mnemonicLanguage` plaintext field using the same `Language.label` spelling, including `english`. Historical keyless vaults restore as English unchanged. Open, restore and fingerprint inspection use that language. Unknown values return `InvalidVaultFailure`. Caller metadata is snapshotted before the keystore read; `mnemonic` and `mnemonicLanguage` are reserved, while historical caller `language` metadata stays untouched. BIP85 child language remains independent of the parent; application paths and Ark index 11811 use English children.

## Networks

`primitives.Network` is sealed over `BitcoinNetwork` and `LiquidNetwork`. Account xpub derivation accepts either, preserving Bitcoin's coin types 0/1 and Liquid's 1776/1. The account index defaults to zero across xpub derivation, Bitcoin descriptors and Bitcoin signing. Bitcoin descriptors return receive/change descriptors and require a script type; Liquid returns a confidential descriptor. Those APIs and `sign.psbt`/`sign.pset` remain chain-specific. The app's older flat enum maps to the shared types at its wallet boundary.

## Recovery

`secret.backup.recoverbull(metadata:)` returns `({EncryptedVault vault, VaultKey key})`. The vault exposes its encoded document through `json`; its derivation path is read from that document, never supplied as a second source of truth. It never contains the key. Both values redact their default string representation; their record does too. Keep the recovery key apart from the vault.

`secrets.recoverbull.restore(vault:, key:)` decrypts and stores the words in the language the vault records internally, returning a `Secret` and the caller's metadata. Unlike direct import, restoration is idempotent when the same secret is already present; it returns the existing handle without overwriting the entry. `secrets.recoverbull.fingerprint(vault:, key:)` instead computes the passphrase-less fingerprint without any keystore read or write. Inspection does not trust a fingerprint from metadata and never imports a temporary secret. RecoverBull presentation keeps a verification status, not a decrypted vault.

## Database keys

`Secrets.databaseKeys(module:)` returns a handle restricted to one module. It offers `getOrCreate(name:)`, `get(name:)` and `reset(name:)`. Inject that handle instead of the full lifecycle service:

```dart
final keys = secrets.databaseKeys(module: 'swaps');
final key = await keys.getOrCreate(name: 'main');
```

Keys are thirty-two random bytes in the existing namespace. `getOrCreate` generates only on a clean miss, atomically within the isolate. `get` never creates a key: a settled miss is `SecretNotFoundFailure`. A present but empty, malformed, displaced or wrongly sized value is `DatabaseKeyCorruptFailure`, and is never overwritten. `reset` deletes the key; the module owner must discard its database as well. Recovery never resets a key automatically.

The public vocabulary does not change persisted key names. Give the key to SQLCipher in raw mode using `DatabaseKey.pragma`; using the hex as a passphrase needlessly runs PBKDF2.

## The exits

The README's operation table is the full inventory — every output, whether it can spend, and what it reveals. Three derivation operations return key material, and none returns the stored mnemonic. Backup keys and database keys are separate outputs in the same inventory:

| | |
|---|---|
| `secret.derive.bip85.hex(…)` | BIP85 child entropy the caller asked this feature to create |
| `secret.derive.bip85.mnemonic(…)` | the same child as words |
| `secret.derive.swapKey(network:)` | the swap-scoped credential boltz takes on every call |

⚠️ **BWK retains keys after the call.** `secret.silentPayments.account(…)` opens the Silent Payments account inside the package, so the words never reach the app — but bwk-dart builds an account from a mnemonic only, and the account it returns holds the keys until it is disposed. It is a capability, not an exit to the host. A key-based bwk constructor (bwk-bitcoin/bwk#114) would let the package pass derived keys instead.

**The stored mnemonic has no exit.** `Secret.revealMnemonic` is `@internal`:
the only callers are this package's own sealed widgets, `MnemonicView`
and `MnemonicChallenge`, and a feature that reaches for it gets an
`invalid_use_of_internal_member` error. The widgets are built through
`secret.widgets`; their constructors are `@internal` too. Showing a user their words is a
display concern, and a display that hands them back has nothing left to
seal — so the host receives each word **as a widget** whose text has no
accessor (`wordBuilder(context, number, Widget word)`, `MnemonicTile.word`),
and arranges widgets. A `Map<int, Widget>` in the callback rebuilds
nothing, and neither does walking the element tree: `PaintedWord` paints
its text through a private render object, so no `Text` or `RichText` of
the mnemonic or the passphrase is ever in the tree, and the render object
keeps the string in library-private fields. What leaves the widgets is
pixels. The host's capture protection blocks a screenshot; it cannot stop
code inside the app reading a rendered image back
(`RenderRepaintBoundary.toImage`), which only review can rule out. Layout
does not leak the words: every painted cell takes the size of the widest
BIP39 word, or of the widest printable ASCII character for a passphrase, in
the style, so what a host can measure (`RenderBox.size`, intrinsic sizes)
follows the word count and the passphrase length, never their content. The
package's own tests read the painted text
through `debugPaintedTextOf`, `@internal` and reachable only from `src/`.
To *compare* words, `verify.mnemonic` answers without exposing anything.

Do not grep for the three — `test/invariants_test.dart` pins the set, so
adding a fourth turns the suite red and names it.

`derive.descriptors.liquid` is not on it, but it is not public either:
lwk's confidential descriptor embeds the SLIP-77 master blinding key, so
whoever holds it sees every amount and asset of that Liquid wallet — a
view key, with no spend authority. The package treats the same string as
secret when lwk writes it to disk (§ The package owns the keystore);
hosts should store and log it as private data.

`backup.recoverbull` is not on this list, but note that its result pairs
ciphertext with the key that opens it: hold both and you hold the
mnemonic. Store them apart.

There is no retained signer. payjoin-ffi's `ProcessPsbt` is a synchronous
`String callback(String psbt)` called from Rust during `finalizeProposal`,
which the asynchronous `sign.psbt` cannot serve directly — so the payjoin
receiver signs in two steps: it asks the proposal for `psbtToSign()`, the
deterministic PSBT the callback will be handed, signs it with
`sign.psbt`, and gives `finalizeProposal` a callback that returns that
result and refuses any other PSBT. Every signature is one call, and no
bdk wallet outlives it.

## BIP85 takes no network

`derive.bip85.*` and the vault's backup key take no network, because
there is no such thing as testnet BIP85: the entropy is an HMAC over a
derived private key, and version bytes never enter it. The package
always derives from the mainnet encoding, which is also the only one
`bip85_entropy` accepts. The app used to pass the wallet's
network-encoded xprv, so BIP85 and vault creation failed on every
non-mainnet wallet.

## Modules

One file per module fronts the others. Open it to know what the module
exposes; everything else in the directory is implementation.

```
lib/secrets.dart          the package: the surface, explicit `show` lists — what a caller can name
lib/src/
  public/                 what you call          Secrets, Secret, the grouped operations, the export lists (types.dart, widgets.dart) — forwards Results, catches nothing
  crypto/crypto.dart      what it computes       derivers/, signers/, backups/, generator, silent_payments
    derivers/derivers.dart one deriver per library  fingerprint, bitcoin, liquid, bip85, boltz — a static namespace
    signers/signers.dart  one signer per chain   bitcoin_signer, liquid_signer, and pset_sighash (the Liquid sighash guard)
    backups/backups.dart  one backup per format  recoverbull — a static namespace
  data/data.dart          where it is kept       the keystore, the two repositories, the one try/catch (boundary.dart)
  domain/domain.dart      what it speaks in      value types, failures
  widgets/widgets.dart    what the user sees     MnemonicView, MnemonicChallenge, SecretWidgets (`secret.widgets`); PaintedWord, PaintedPassphrase and PaintedMnemonic stay unexported
  testing/testing.dart    the test seam          the in-memory keystore, behind lib/testing.dart — test code only
```

`lib/testing.dart` is the package's second public library. It is outside
`src/`, so `implementation_imports` does not cover it; an invariant test
does — nothing under this package's `lib/` may import it, and consumers must import it from
`test/` alone.

Each entry point is a barrel with an explicit `show` list — it defines
the module's surface rather than letting it leak — and may hold what the
module shares (`signers.dart` holds the one rule every signer follows).
Two rules make this real, and both are tests:

- **Cross-module imports go through the entry point.** `public/` may import
  `crypto/crypto.dart`; if it reaches for `crypto/signers/bitcoin_signer.dart`
  the suite fails. Inside a module, files import each other freely.
- **Foreign dependencies are confined to the module that owns them.**
  bdk, lwk, boltz, bwk and recoverbull live under `crypto/`; the keystore and
  its federated platform packages under `data/` and `testing/`; Flutter
  under `widgets/`, `data/` and `testing/` (the plugin's
  `PlatformException`); `domain/` imports pure value dependencies only, including the existing BIP39 `Language` enum through `show Language` — it needs no device to be verified; `public/` orchestrates
  and computes nothing.

**Derivers are static.** `Deriver.bitcoin.xpub(…)`, `Deriver.bip85.hex(…)`,
`Deriver.boltz.swapKey(…)`: each is a pure function of material, pinned
by `test/derivation_vectors_test.dart`, with nothing to inject and
nothing to mock — so `Secret` calls them as a namespace. Same for
`Signer.bitcoin` / `Signer.liquid` and `Backup.recoverbull`: **nothing
under `crypto/` has a field.** The one host resource any of it needs,
lwk's scratch directory, is a parameter of the `signPset` call, not of
a signer — so `Secret` carries only what genuinely holds state: the
repository (the serialised keystore queue) and that closure.

**Adding a signer** (Ark is the expected next one): a `<chain>_signer.dart`
under `crypto/signers/`, exported from `signers.dart`; it consumes the BIP39 seed or a derived key. An English-only word adapter must explicitly refuse other languages before calling its library; a `static const` on `Signer`; the operation on `Secret`
beside the others. If the library needs a host resource, it is a
parameter of the operation, never a field — that is what keeps the
namespace `const`. There is deliberately no common
interface — Bitcoin needs a script type and Liquid does not — and nothing calls a signer
polymorphically. What scales is the directory, the shared rule and the
import invariant.

Boltz is not a signer here and will not become one. The swap key is a
delegated credential by design — a separate mnemonic that `swaps` stores
and signs with on its own — and signing a swap is a protocol (claim,
refund, MuSig2 with the server), not a signature. The right treatment of
a legitimate exit is the one it has: named, logged, pinned by the
invariant test.

## How to audit this package

The boundary has structural checks in `test/invariants_test.dart` and `test/internal_seal_test.dart`, which uses the resolved element model:

| property | what the test checks |
|---|---|
| every failure is built in the data layer | no `SecretFailure` is constructed outside `src/data/boundary.dart`, `src/data/secret_repository.dart` and `src/data/database_key_repository.dart`; `public/` catches nothing |
| the grouped API adds nothing | `src/public/extensions.dart` contains no `await`, no collaborator, no statement body |
| material leaves at four named methods | the set of `Secret` methods returning material is exactly `{revealMnemonic, bip85Hex, bip85Mnemonic, swapKey}` — and `revealMnemonic` is `@internal` |
| the public surface is a literal list | the export graph is walked and compared name for name |
| modules are fronted by their entry point | every cross-module import targets `<module>/<module>.dart` |
| foreign dependencies stay in their module | bdk/lwk/boltz/bwk/recoverbull only under `crypto/`, the keystore only under `data/` and `testing/`, Flutter only under `widgets/`, `data/` and `testing/`, only pure value dependencies under `domain/`, including the BIP39 `Language` enum (no mnemonic operations) |
| the testing library never reaches production code | nothing under this package's `lib/` imports `package:secrets/testing.dart` or `src/testing/` |
| nothing unexported is constructible from outside | every public constructor of an unexported class under `lib/src/` is `@internal` — a dot shorthand (`.new()`) builds a type from context alone, without naming or importing it |
| no exported signature hands out an unexported type | no exported, non-`@internal` member mentions one in its parameters or return type |

The on-disk format never moving is pinned byte for byte by
`test/secret_model_golden_test.dart`. The CI-only `make custody-ci-check` refuses any `// ignore:` of
`invalid_use_of_internal_member` in the workspace — `cannot-ignore` does not
hold that diagnostic on Dart 3.12.2 — and any import of `flutter_secure_storage`
or `package:secrets/src/` outside the package, the app's own secure store
excepted. The `PR custody review` workflow comments on a pull request that
adds one, asking the contributor why.

Local `make custody-check`, included in `make checks`, requires only Dart. It resolves production Dart symbols to reject known private-key derivation and vault-opening operations outside `secrets`. Its named exceptions cover swap-scoped credentials and the public-only xpub decoding adapter. Public-key operations, mnemonic validation and formatting of an exported BIP85 child remain valid. The gate also rejects imports or exports of `secrets/testing.dart` and references to its test-support declarations throughout application and workspace production code, including aliases and re-exports. Unresolved production code fails the gate. This is an operation policy, not complete data-flow analysis or proof that arbitrary strings cannot carry secrets. Pre-import scanning, RecoverBull restoration and inspection are migrated.

So an audit is: run the suite, then read four files —
`src/public/secret.dart` for what the package does, `src/data/boundary.dart`
for what it may report, `lib/secrets.dart` for what it exposes, and
`lib/testing.dart` for the one seam that bypasses the keystore, and where
it may be used.

**What the suite can and cannot reach.** bdk ships as a native asset and
loads under `flutter test`, so `generate`, the Bitcoin descriptors,
and `signPsbt` run for real in the unit suite — and every
xpub the package derives is checked against bdk deriving the same path
independently (`test/derivation_mappings_test.dart`). lwk and boltz are
flutter_rust_bridge plugins with no host library: `liquidDescriptor`,
`signPset` and `swapKey` are reached only by `integration_test/` on a
device, and only their pre-FFI refusals are unit-tested — the Liquid
sighash guard among them, which reads the PSET in pure Dart. The swap key
is pinned from both sides: the host suite checks that the package's BIP85
child 26589 is boltz's published swap mnemonic
(`test/swap_key_vector_test.dart`), and the device test checks that
`swapKey` returns exactly that child.

The repository is the boundary (AGENTS.md, rule 11): every repository
method returns a `Result`, and `Secret` never holds material — it hands the
repository a closure, which runs on material that exists only for that
call (`use`, `useMnemonic`). Two failures tell a caller *which side* went
wrong: `FetchSecretFailure` is the keystore, `UseSecretFailure` is
the engine — a PSBT that does not parse never reads as an unreadable seed.
An `Error` raised under the boundary is a bug and keeps propagating —
but re-thrown with its type only, never a message this package did not
write. A value that does not derive to the key it is filed under is a
`FingerprintMismatchFailure`, and the entry is left exactly as it is. The app can ask the user to re-import the correct backup; the package never silently re-files the stored material.

## Where checks live

A reader should be able to predict where a validation is, so:

1. **Anything arriving from a source we do not control is parsed where it
   arrives** — `fromJson`, and nowhere else. The keystore is such a
   source: on Linux and Windows any process of the same user can rewrite
   an entry, and an older build may have written another shape.
2. **Value types built from raw input at many call sites validate in
   their constructor** — `Fingerprint`, `DatabaseKey`. They are small
   parse boundaries of their own.
3. **Invariants belong to the type, not to a code path.**
   `MnemonicSecretModel` and `BytesSecretModel` have private constructors
   and validating factories, so a word count BIP39 does not define is
   refused however the model was built — not only on the way in from
   JSON. This matters because the listing path never builds an entity:
   `describeAll` projects the model straight to `SecretInfo`, so an entry
   with no words would otherwise appear as a wallet.
4. **Aggregates assembled internally from already-checked parts do not
   re-check** — and their constructors stay unreachable from outside.

## Rules for contributors

**The repository is concrete, by derogation** (AGENTS.md rule #6,
2026-09-15). No `abstract interface class` in `domain/`, and no injected
keystore: the package builds its own `flutter_secure_storage` and hands
one to nobody. An interface would put a substitutable seam exactly where
the security property says there must not be one — reaching the seeds
should mean constructing the plugin yourself and hardcoding the prefix,
which is visible in review. The test seam is one layer lower, at
`FlutterSecureStoragePlatform.instance`, replaced by
`package:secrets/testing.dart`; that is why the suite exercises the real
key composition, JSON encoding and `PlatformException` translation.
`Secrets` and `Secret` are `final` for the same reason — a consumer's
test substitutes the platform, it does not mock the façade. Recorded in
`ARCHITECTURE.md`, § Monorepo; specific to this package.

**Never import `package:secrets/src/...`.** The `src/` tree is private
and crossing it defeats the package. The app's root `analysis_options.yaml`
makes `implementation_imports` an **error**, and `invalid_use_of_internal_member`
— the seal on `Secret.revealMnemonic` and on every constructor the
package does not export — an error too. Workspace members
that ship their own options file inherit both at `info`/`warning` from
`package:lints`; none of them imports this package, and CI's
`--fatal-infos --fatal-warnings` catches the day one does.

**`SecretMaterial` is never serialisable.** It has no `toJson`, no mapper, no
codegen mixin — so encoding key material by accident is a compile error
rather than a leak. Persistence goes through `SecretModel` alone.

**`SecretModel`'s JSON shape is frozen.** Those bytes are already on
users' devices under `seed_<fingerprint>`. Any drift orphans wallets with
no migration path short of asking the user for their backup.
`test/secret_model_golden_test.dart` pins the exact strings — if it goes
red, the on-disk format moved. The domain names `Seed` and `SecretKind.seed` still serialize as `runtimeType: "bytes"` with the historical `bytes` field.

**Absence is only ever concluded from a full read.** `flutter_secure_storage`
has been observed reporting an entry as empty or absent instead of
raising. A false "present" is a benign read error; a false "absent" tells
the user their wallet is gone. That is why there is no existence check to
trust, and why every read that decides something goes through one primitive,
`_settle`: a null or a `""` is re-read, a `""` anywhere is sticky (the key
exists), a read that keeps throwing is a read failure, and a locked keystore
passes through at once. It has two budgets, because a re-read only costs when
the answer is "absent":

| budget | where | reads | worst case | why |
|---|---|---|---|---|
| `settled` | `fetch`, `DatabaseKeys.get` | 5, 300 ms doubling | ~4.5 s | outside the lock; absence is exceptional, so only a genuine miss pays |
| `underLock` | `import`/`generate`/`recoverbull.restore`, the first `DatabaseKeys.getOrCreate` | 2, 300 ms apart | 300 ms | inside a composed write, where absence is the normal outcome of a first store; the full budget would add ~4.5 s to every new secret and hold every other composed operation behind it |

Two reads stay outside it on purpose. `exists` is one read: a false "no"
lets a duplicate import reach `storeSecret`, which settles on its own. `list`
is one `readAll`, with no retry. Every rescue logs `RETRY_RESCUE` with its
attempt number and budget: if rescues never come after the second read, one
budget of two is enough everywhere.
The converse holds too: a value that is present but unreadable is a
`FetchSecretFailure`, never a `SecretNotFoundFailure` — callers treat
not-found as "the seed is gone", and a corrupt entry is not that. The
same goes for a read that throws on its last attempt, for a `""` seen on
any attempt, and for stored words that no longer pass bip39: read
failures, not absences. Only a clean `null` on the read that was allowed
to settle, with no `""` before it, concludes absence. The write side
agrees: an entry that reads back empty is **occupied**, and `storeSecret` refuses to write over it exactly as they refuse a value
that does not parse — the seed twin of the module-key rule, pinned by
`test/fss9_cohort_test.dart` and `test/ownership_test.dart`.

## The cohort whose secrets are not there

Android installs from 6.5.2 kept their secrets in Jetpack Security's
EncryptedSharedPreferences, read through the `flutter_secure_storage` 9
plugin. **That plugin is gone and there is no fallback** (decision of
2026-09-15): one storage generation, chosen in
`lib/core/storage/storage_locator.dart`, no probing, no
`seed_store_type` flag. Those entries are simply not readable any more.

So the guarantee is not that they can be read. It is that the app can
tell this apart from everything else and says the right thing:

| what the device looks like | what the package reports | what the app does |
|---|---|---|
| nothing under `seed_` | `list()` → `Ok([])`, `fetch` → `SecretNotFoundFailure` after the full retry budget | `AppStartupMissingDefaultSecretFailure` at startup → the user re-enters the recovery phrase, checked against the missing fingerprint before it is stored |
| an fss9 value still under `seed_<fp>` | `list()` includes an `UnreadableSecret`; `fetch` → `FetchSecretFailure` | the generic failure — **never** a restore offer, because the bytes may still be recoverable |
| unmigrated EncryptedSharedPreferences data in the plugin's file | the pinned plugin (10.3.3, `migrateOnAlgorithmChange: false`) refuses to initialise on every call: `list()` and `fetch` → `FetchSecretFailure`, `import` and `DatabaseKeys.getOrCreate` → `StoreSecretFailure`, nothing written | the generic failure, as above |
| the keystore is locked | `KeystoreLockedFailure` | `KeychainLockedException` → wait for unlock and retry, no screen |

`test/fss9_cohort_test.dart` pins the first three — the fake keystore cannot model the plugin refusing to initialise, which is established from the plugin's source — including that nothing is
ever written over an unreadable entry: a backup is the cohort's way back,
and an overwrite would remove the only thing that could still be read.

Pre-v5 (0.x, "BULL") installs are not migrated either (decision of
2026-09-23): the storage generation that could read their entries is the
same one, and the app's rescue screen for that cohort was removed with it.
Their way back is the same — a backup.

## The package owns the keystore

`FlutterSecureStorageDatasource` holds the only `FlutterSecureStorage`
instance in the package, and no constructor accepts one from outside. No
exported type can read it, so reaching the seeds means constructing the
plugin yourself and hardcoding the `seed_` prefix — visible in review,
rather than an ordinary-looking call on an object you were given. In a
single process this is not a hard guarantee; it removes the
legitimate-looking path, which is the part that matters.

Its Android options — `resetOnError: false`, `migrateOnAlgorithmChange:
false`, never delete, never migrate — hold only while every
`FlutterSecureStorage` client in the engine passes the same ones: the
pinned plugin keeps one native store per preferences name and freezes the
options of whichever client initialises it first. Today there is one other
client, the app's `lib/core/storage/storage_locator.dart`, and it passes
the same options. A new client with the defaults would re-enable
delete-on-error for the seeds.

That one type also owns the whole keyspace — `seed_<fingerprint>` for
secrets, `com.bullbitcoin.secrets/<kind>/<package>/<name>` for the keys
held on other modules' behalf — so both namespaces are read side by side
in one file. They differ because the first is frozen and predates the
convention; do not harmonise them.

**One lock, for the composed sequences.** A `static` lock guards the
package's read-modify-writes — `storeSecret`, `trashSecret`,
`fetchOrCreateModuleKey`, `deleteModuleKey` — and nothing else.
Unserialised, two first asks for the same module key each read a miss,
each generate, and the second write wins: the first caller holds a key
that opens nothing, and a database nobody can read again. Only holding
the whole sequence prevents that.

Single calls are not locked. The plugin serialises them itself on every
platform — Android posts each call to one `HandlerThread`, Darwin uses a
serial `DispatchQueue`, Linux runs on the platform thread, Windows takes
a mutex — verified against `flutter_secure_storage` 10.3.3 and unchanged
in 11.1.1. That is an implementation property, not a contract; if it
changed, wrapping the four primitives is one line each.

This lock does **not** close
[#592](https://github.com/juliansteenbakker/flutter_secure_storage/issues/592),
and must not be described as doing so. An earlier version of this package
claimed exactly that, and the claim was wrong twice over: the queue it
described was per *datasource instance*, and `Secrets` builds two — one
under `SecretRepository`, one under `DatabaseKeyRepository` — so even "hold one
`Secrets` per process" did not buy the property. A guard whose stated
reason is wrong is worse than no guard: it gets believed.

The lock is not reentrant, so the rule in the file is absolute: the
primitives never take it, and a composed operation takes it once and
calls only primitives. A new composed operation takes the lock too.

It is also **per isolate** — a `static` is. The app's WorkManager isolate
builds a second `Secrets` through its own composition root, so the
guarantee holds only while no background task mutates the keystore. True
today, and `test/core_test/background_tasks/background_tasks_keystore_test.dart`
in the app keeps it true.

Tests substitute the store below the package, at
`FlutterSecureStoragePlatform.instance`. That keeps the package's real
key composition, JSON encoding and `PlatformException` translation inside
the test — but the platform instance is process-wide, so two stores
cannot be live at once.

The host supplies one thing, and it is not a handle on anything:

```dart
final secrets = Secrets(
  scratchDirectory: () async => (await getTemporaryDirectory()).path,
);
```

A directory lwk may use as a scratch cache while signing, since
`Wallet.init` has no in-memory persister — and it writes a wallet cache
there that carries the confidential descriptor, hence the SLIP-77 blinding
key. So: the OS **temporary** directory, which the OS purges and iOS
excludes from backups on its own, never the documents directory. Each
signature gets a fresh `lwk_sign_*` directory, deleted in a `finally`;
before creating one, and once when `Secrets` is constructed, the package
sweeps `lwk_sign_*` siblings older than ten minutes — long enough that a
signature still in flight (they take seconds) is never touched, short
enough that a leftover from a process that died does not outlive the next
launch. One entry's failure costs that entry, and an mtime in the future
is a clock that moved, not a directory that is old. Bitcoin signing writes
nothing — bdk builds its wallet on `Persister.newInMemory()` and throws it
away. The parameter is a temporary wart: it disappears the day lwk-dart
binds its signer directly, which is why it is a bare closure and not a
type.

No signer touches the app's wallet databases: signing needs the keys and
the descriptors, not the transaction history. The bdk wallet is built
from the Dart master xprv of the language-aware BIP39 seed with the same `SignOptions` the app's own datasource
used before the migration — a refactor must not change how signatures
are produced.

**Neither chain lets a PSBT or PSET choose what the signature commits
to.** bdk refuses any input whose sighash is not `ALL`
(`allowAllSighashes: false`). lwk_signer 0.18.0 signs with whatever
sighash the PSET names, so `signPset` reads every input's
`PSBT_IN_SIGHASH_TYPE` first, in pure Dart (`crypto/signers/pset_sighash.dart`),
and refuses anything but absent or `SIGHASH_ALL`, and anything it cannot
read. PSETs lwk builds for the app leave the field absent. Beyond the
sighash, the package applies no policy on outputs, fees or inputs: it
signs the inputs its keys own, and deciding what is acceptable to sign is
the caller's.

## Read-only Android legacy backup

`Secrets.legacyBackup` runs before normal foreground initialization and before a persisted background job opens the app's shared secure-storage client. A null result permits normal startup. A non-null list leads to the terminal backup screen; failures lead to its support state, never to a fresh wallet. Every normal package operation also checks the physical Android inventory before initializing FSS. Legacy handles use a separate read-only datasource and cannot write or delete.

The private Android reader parses preference XML without opening SharedPreferences, whose own initialization can restore backup files. It has no write, reset, key generation or migration operation. Backups, corrupt XML, duplicate keys, unsupported formats, missing keys and changed snapshots are fixed-code failures. A prior database, Hive box or historical store flag prevents an empty inventory from authorizing normal startup.

ESP uses existing encrypted or historical cleartext keysets through Tink 1.21.0, already supplied by the exactly pinned FSS 10.3.3 Android dependency. CBC unwraps the existing AES key with the application's historical RSA alias. A failed develop initialization may have added GCM markers and a GCM key; failed GCM authentication then permits only a successful complete CBC read, never default plugin initialization. Mixed or unreadable values are refused. CBC padding is not authentication: every displayed envelope must parse as SecretModel, pass BIP39 validation and derive to its storage-key fingerprint. Seed-only or incomplete inventories remain blocked.

No material is retained in the returned handles. MnemonicView rereads through the native reader inside its sealed state and paints words and passphrases outside semantics. The host enables screen privacy before mounting the views and offers reinstall instructions only after every view reports a successful read. No old preferences are migrated, rewritten or deleted. Android uninstall and standard restoration are explicit user steps after a verified backup.

Current OAEP/GCM stores are admitted only after unwrapping the existing canonical key and authenticating every raw value; markers alone do not authorize FSS. Empty current stores still need a usable existing key. Synthetic Java tests compare bytes on success and failure, and Dart tests cover the channel, model and fingerprint boundaries. These checks do not replace device upgrade and restore evidence.
