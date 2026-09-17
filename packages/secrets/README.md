# secrets

User secret material — BIP39 mnemonics and raw seeds — behind a custody
boundary.

## The contract

**No exported type carries key material.** `Secrets` is the lifecycle —
make a secret, find one, forget one — and hands back a `Secret`, which
carries every operation as a flat method:

```dart
await secret.xpub(network: n, scriptType: s);
await secret.signPsbt(psbt, network: n, scriptType: s);
await secret.backupVault(metadata: meta);
```

`Secret` is one class in one file, and that is deliberate: it is the
audit surface. Reading it once shows every operation the package can
perform and every one that hands back material.

The grouped spelling is sugar over those same methods — zero-cost
`extension type`s that forward and hold no behaviour of their own:

```dart
final secret = switch (await secrets.fetch(Fingerprint(wallet.masterFingerprint))) {
  Ok(:final value) => value,
  Err(:final failure) => return failure,
};

secret.info                                      // a plain value, for state
await secret.derive.xpub(network: n, scriptType: s);
await secret.derive.descriptors.liquid(network: n);   // a PassphraseScope
await secret.derive.descriptors.bitcoin(network: n, scriptType: s);
await secret.derive.bip85.hex(numBytes: 32, index: 0);
await secret.sign.psbt(psbt, network: n, scriptType: s);
await secret.verifyWords(candidate);
```

Everything above returns something *derived* from the secret — a public
key, a public descriptor, a signature. The mnemonic never crosses the
boundary. Use whichever spelling reads better; they compile to the same
call, and `test/invariants_test.dart` asserts that the sugar can never
be more than a forward.

Identity is `primitives.Fingerprint`: 8 lowercase hex, validated on the
way in, and the same type the rest of the monorepo uses to name a seed.
Networks, script types, xpub formats, `Result` and `Failure` come from
`primitives` too — this package adds no vocabulary the monorepo already
has.

## ⚠️ Passphrase — two operations derive from the words alone

> ⚠️ **A BIP39 passphrase is honoured by Bitcoin derivation, signing and
> the swap key.** Liquid and the RecoverBull vault derive from the
> **words alone**. Two secrets that share words but differ by passphrase
> — same `SecretInfo.mnemonicFingerprint`, different `id` — therefore
> share a Liquid wallet, and a vault of one restores as the other.

**Nothing is silent any more.** Both operations return a
`PassphraseScope<T>`, which is `sealed`, so a caller cannot reach the
value without meeting the case where the passphrase was left out:

```dart
switch (await secret.backup.vault(metadata: meta)) {
  Ok(value: WholeSecret(:final value)) => save(value),
  Ok(value: WordsOnly(:final value)) =>
      saveAndTellTheUserToKeepTheirPassphrase(value),
  Err(:final failure) => report(failure),
}
```

`SecretInfo.scope` decides it, once, for all of them — an invariant test
holds it to that, which is also how `liquidDescriptor` is covered
without the FFI.

| operation | what happens | why |
|---|---|---|
| `derive.descriptors.liquid` | passphrase takes no part; result is `WordsOnly` | lwk has no passphrase parameter at any layer (verified below) |
| `sign.pset` | passphrase takes no part | same, and consistently — which is what keeps the signature matching the descriptor |
| `backup.vault` | words sealed, passphrase not; result is `WordsOnly` | the vault plaintext carries `mnemonic` only — the format every existing vault and the key server speak |
| `Secrets.restoreVault` | pass `passphrase:` to restore the wallet the user had | the file cannot carry it, so the user supplies it; without it the result is `WordsOnly` and the secret stored is the passphrase-less sibling |
| `derive.swapKey` | **passphrase included** | `walletPassphrase` is sent (2026-09-15). Keys stored before that were derived from the words alone and are **not** re-derived — `swaps` asks only when it holds none |

**Verified, so nobody has to re-verify** (2026-09-14):

1. `bull_sdk` binding — `Descriptor.newConfidential({network, mnemonic})`
   and `Wallet.signTx({network, pset, mnemonic})`; no `passphrase` or
   `password` anywhere in the lwk binding.
2. lwk-dart glue (`f554c78`, `rust/src/public/descriptor.rs:17` and
   `wallet.rs:554`) — both build `SwSigner::new(&mnemonic, is_mainnet)`.
3. `lwk_signer` 0.18.0, `src/software.rs:103` —
   `let seed = mnemonic.to_seed("");` The passphrase is hard-coded empty.
   The only other root is `SwSigner::from_xprv`, which the binding does
   not expose.

**Consequences for the app**

- A Liquid wallet imported with a passphrase watches the **same
  addresses** as the passphrase-less one: same confidential descriptor,
  same funds, two wallet ids. The app logs `LIQUID_WORDS_ONLY` where the
  metadata is built.
- A user who relies on the passphrase for plausible deniability has none
  on Liquid: the passphrase-less words open the Liquid wallet.
- A vault of a passphrase secret restores the passphrase-less wallet
  **unless the passphrase is passed back** to `restoreVault`. The backup
  screens hold `vaultExcludesPassphrase` for exactly that message.

**What is left, and why it is not done in passing** — lifting the Liquid
case moves the Liquid wallet of every passphrase user who already has
one, so it needs a migration decision, not a fix:

- Liquid: a passphrase-aware constructor (or `SwSigner::from_xprv`)
  bound in lwk-dart — asked of the maintainer — then a migration
  decision for existing passphrase wallets.
- vault: an additive `passphrase` field in the plaintext would remove the
  `WordsOnly` case entirely, but it is a format change, and the key
  server speaks the current one.

## Database keys

`Secrets.databaseKey` hands a package the encryption key for its own
database — thirty-two random bytes, generated on first ask, kept in this
package's keystore namespace. It is not user material: it opens one local
database and nothing else.

Generated **only** on a clean miss. A stored value that is present but
unusable — empty, not our JSON, filed under another name, not 32 bytes of
hex — is a `DatabaseKeyCorruptFailure`, and the bytes are left exactly as
they are. Writing over them is the one irreversible act available here:
the database they opened could then never be read, by anyone, ever.
Refusing costs an unopenable database too, but it keeps the only thing
that could still open it. Discarding the database and its key together is
the module owner's decision — this package does not know whether that
database is a rebuildable cache or the only copy of something. When the
owner decides, `Secrets.resetDatabaseKey(package:, name:)` is the one
destructive call: it deletes the key, so the database must go in the same
step. Nothing on a recovery path calls it.

Compose rather than injecting `Secrets`, so a package can only ever name
its own keys:

```dart
Swaps(databaseKey: (name) => secrets.databaseKey(package: 'swaps', name: name));
```

Give the bytes to SQLCipher in raw mode — `DatabaseKey.pragma` spells it.
A bare hex string makes SQLCipher treat an already-random key as a
passphrase and run 256 000 PBKDF2 rounds over it on every open.

## The exits

Material leaves through three methods, and none of them is the stored
mnemonic:

| | |
|---|---|
| `secret.derive.bip85.hex(…)` | BIP85 child entropy the caller asked this feature to create |
| `secret.derive.bip85.mnemonic(…)` | the same child as words |
| `secret.derive.swapKey(network:)` | the swap-scoped credential boltz takes on every call |

**The stored mnemonic has no exit.** `Secret.revealMnemonic` is `@internal`:
the only callers are this package's own sealed widgets, `MnemonicView`
and `MnemonicChallenge`, and a feature that reaches for it gets an
`invalid_use_of_internal_member` error. Showing a user their words is a
display concern, and a display that hands them back has nothing left to
seal — so the host receives each word **as a widget** whose text has no
accessor (`wordBuilder(context, number, Widget word)`, `MnemonicTile.word`),
and arranges widgets. A `Map<int, Widget>` in the callback rebuilds
nothing. What remains possible is walking one's own element tree for the
inner `Text`: a deliberate act that reads as one in review, which is the
line every sealed UI draws. To *compare* words, `verifyWords` answers
without exposing anything.

Do not grep for the three — `test/invariants_test.dart` pins the set, so
adding a fourth turns the suite red and names it.

`backup.vault` is not on this list, but note that its result pairs
ciphertext with the key that opens it: hold both and you hold the
mnemonic. Store them apart.

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
  public/                 what you call          Secrets, Secret, the grouped sugar, the sealed widgets, types — forwards Results, catches nothing
  crypto/crypto.dart      what it computes       derivers/, signers/, backups/, generator
    derivers/derivers.dart one deriver per library  identity, bitcoin, liquid, bip85, boltz — a static namespace
    signers/signers.dart  one signer per chain   bitcoin_signer, liquid_signer
    backups/backups.dart  one backup per format  recoverbull — a static namespace
  data/data.dart          where it is kept       the keystore, the two repositories, the one try/catch (boundary.dart)
  domain/domain.dart      what it speaks in      value types, failures
```

Each entry point is a barrel with an explicit `show` list — it defines
the module's surface rather than letting it leak — and may hold what the
module shares (`signers.dart` holds the one rule every signer follows).
Two rules make this real, and both are tests:

- **Cross-module imports go through the entry point.** `public/` may import
  `crypto/crypto.dart`; if it reaches for `crypto/signers/bitcoin_signer.dart`
  the suite fails. Inside a module, files import each other freely.
- **Foreign dependencies are confined to the module that owns them.**
  bdk, lwk, boltz and recoverbull live under `crypto/`; the keystore
  under `data/`; `domain/` imports nothing foreign — it is the one
  directory that needs no device to be verified; `public/` orchestrates and
  computes nothing.

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
under `crypto/signers/`, exported from `signers.dart`; it takes
`MnemonicMaterial` and turns it into a sentence with `mnemonicSentence`
and nothing else; a `static const` on `Signer`; the operation on `Secret`
beside the others. If the library needs a host resource, it is a
parameter of the operation, never a field — that is what keeps the
namespace `const`. There is deliberately no common
interface — Bitcoin returns a reusable closure and needs a script type,
Liquid is one-shot and does not — and nothing calls a signer
polymorphically. What scales is the directory, the shared rule and the
import invariant.

Boltz is not a signer here and will not become one. The swap key is a
delegated credential by design — a separate mnemonic that `swaps` stores
and signs with on its own — and signing a swap is a protocol (claim,
refund, MuSig2 with the server), not a signature. The right treatment of
a legitimate exit is the one it has: named, logged, pinned by the
invariant test.

## How to audit this package

Seven properties carry the boundary, and each is an assertion in
`test/invariants_test.dart` rather than something to establish by
reading:

| property | what the test checks |
|---|---|
| every failure is built in the data layer | no `SecretFailure` is constructed outside `src/data/boundary.dart` and `src/data/secret_repository.dart`; `public/` catches nothing |
| the grouped API adds nothing | `src/public/extensions.dart` contains no `await`, no collaborator, no statement body |
| material leaves at four named methods | the set of `Secret` methods returning material is exactly `{revealMnemonic, bip85Hex, bip85Mnemonic, swapKey}` — and `revealMnemonic` is `@internal` |
| the public surface is a literal list | the export graph is walked and compared name for name |
| the passphrase caveat has one author | `WordsOnly`/`WholeSecret` are constructed only in `SecretInfo.scope` |
| modules are fronted by their entry point | every cross-module import targets `<module>/<module>.dart` |
| foreign dependencies stay in their module | bdk/lwk/boltz/recoverbull only under `crypto/`, the keystore only under `data/`, nothing foreign under `domain/` |

The on-disk format never moving is pinned byte for byte by
`test/secret_model_golden_test.dart`.

So an audit is: run the suite, then read three files —
`src/public/secret.dart` for what the package does, `src/data/boundary.dart`
for what it may report, `lib/secrets.dart` for what it exposes.

The repository is the boundary (AGENTS.md, rule 11): every repository
method returns a `Result`, and `Secret` never holds material — it hands the
repository a closure, which runs on material that exists only for that
call (`use`, `useMnemonic`). Two failures tell a caller *which side* went
wrong: `SecretFetchFailure` is the keystore, `SecretDerivationFailure` is
the engine — a PSBT that does not parse never reads as an unreadable seed.
A value that does not derive to the key it is filed under is a
`SecretIdentityMismatchFailure`, and the entry is left exactly as it is:
`Secrets.repairIdentity(id)` re-files it under the identity it really
has, inside the package, so nothing has to leave to fix it. The move is a
write then a delete, so a crash leaves both copies rather than none, and
a true identity already held by a different secret refuses instead of
overwriting — the user re-imports their backup for the original
fingerprint then.

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
and crossing it defeats the package. Enable the `implementation_imports`
lint as an error in the app's `analysis_options.yaml`; until then the
boundary is a convention, not a rule.

**`SecretMaterial` is never serialisable.** It has no `toJson`, no mapper, no
codegen mixin — so encoding key material by accident is a compile error
rather than a leak. Persistence goes through `SecretModel` alone.

**`SecretModel`'s JSON shape is frozen.** Those bytes are already on
users' devices under `seed_<fingerprint>`. Any drift orphans wallets with
no migration path short of asking the user for their backup.
`test/secret_model_golden_test.dart` pins the exact strings — if it goes
red, the on-disk format moved.

**Absence is only ever concluded from a full read.** `flutter_secure_storage`
has been observed reporting an entry as empty or absent instead of
raising. A false "present" is a benign read error; a false "absent" tells
the user their wallet is gone. That is why there is no existence check to
trust and why a genuine miss costs the full retry backoff.
The converse holds too: a value that is present but unreadable is a
`SecretFetchFailure`, never a `SecretNotFoundFailure` — callers treat
not-found as "the seed is gone", and a corrupt entry is not that. The
same goes for a read that throws on its last attempt, and for stored
words that no longer pass bip39: read failures, not absences. An empty
string is retried exactly like a null — the plugin has been seen
returning `""` for an entry that exists. Only a clean `null` on the read
that was allowed to settle concludes absence.

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
| nothing under `seed_` | `list()` → `Ok([])`, `fetch` → `SecretNotFoundFailure` after the full retry budget | `MissingDefaultSecretException` at startup → the restore flow, `hasBackup` on |
| an fss9 value still under `seed_<fp>` | skipped by `list()`; `fetch` → `SecretFetchFailure` | the generic failure — **never** a restore offer, because the bytes may still be recoverable |
| the keystore is locked | `SecretStoreLockedFailure` | `KeychainLockedException` → wait for unlock and retry, no screen |

`test/fss9_cohort_test.dart` pins all three, including that nothing is
ever written over an unreadable entry: a backup is the cohort's way back,
and an overwrite would remove the only thing that could still be read.

## The package owns the keystore

`FlutterSecureStorageDatasource` holds the only `FlutterSecureStorage`
instance in the package, and no constructor accepts one from outside. No
exported type can read it, so reaching the seeds means constructing the
plugin yourself and hardcoding the `seed_` prefix — visible in review,
rather than an ordinary-looking call on an object you were given. In a
single process this is not a hard guarantee; it removes the
legitimate-looking path, which is the part that matters.

That one type also owns the whole keyspace — `seed_<fingerprint>` for
secrets, `com.bullbitcoin.secrets/<kind>/<package>/<name>` for the keys
held on other modules' behalf — so both namespaces are read side by side
in one file. They differ because the first is frozen and predates the
convention; do not harmonise them.

**One lock, for the composed sequences.** A `static` lock guards the
package's read-modify-writes — `storeSecret`, `fetchOrCreateModuleKey`,
`deleteModuleKey` — and nothing else.
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

Tests substitute the store below the package, at
`FlutterSecureStoragePlatform.instance`. That keeps the package's real
key composition, JSON encoding and `PlatformException` translation inside
the test — but the platform instance is process-wide, so two stores
cannot be live at once.

The host supplies one thing, and it is not a handle on anything:

```dart
final secrets = Secrets(
  scratchDirectory: () async =>
      (await getApplicationDocumentsDirectory()).path,
);
```

A directory lwk may use as a scratch cache while signing, since
`Wallet.init` has no in-memory persister. Bitcoin signing writes nothing
— bdk builds its wallet on `Persister.newInMemory()` and throws it away.
The parameter is a temporary wart: it disappears the day lwk-dart binds
its signer directly, which is why it is a bare closure and not a type.

No signer touches the app's wallet databases: signing needs the keys and
the descriptors, not the transaction history. The bdk wallet is built
from the BIP39 words with the same `SignOptions` as
`BdkWalletDatasource.signPsbt` — a refactor must not change how
signatures are produced.
