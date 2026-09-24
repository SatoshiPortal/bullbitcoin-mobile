# secrets

User secret material — BIP39 mnemonics and raw seeds — behind a custody boundary. One door in, and everything you can do is a method on what comes out.

## One entry point

```dart
final secrets = Secrets(
  scratchDirectory: () async => (await getTemporaryDirectory()).path,
);

// A secret is created once — generated, or imported from the user's words —
// and known from then on by its fingerprint: the BIP32 master fingerprint,
// eight hex characters, derived from the words (and the passphrase, if any).
final created = await secrets.generate();                      // twelve words
final imported = await secrets.import(words: words, passphrase: passphrase);

// The fingerprint is the only thing a caller keeps. It identifies a wallet's
// seed, it is safe to log and to store in a database, and it is what every
// later call takes.
final Fingerprint id = ok(created).id;

// Anywhere else, any time later: the fingerprint back into a handle.
final secret = switch (await secrets.fetch(id)) {
  Ok(:final value) => value,
  Err(:final failure) => return failure,          // SecretNotFoundFailure, or a keystore failure
};

// Before importing, the fingerprint the words *would* have — the duplicate check.
final candidate = ok(await secrets.idOf(words: words, passphrase: passphrase));
if (ok(await secrets.exists(candidate))) return alreadyImported;
```

`Secrets` is the lifecycle — `generate`, `import`, `fetch`, `list`, `exists`, `idOf`, `trash`, `restoreVault`, `databaseKey`. It hands back a `Secret`: a handle that holds no key material, only `info` (identity and shape, safe to log) and `id`, its `Fingerprint`. The words themselves are consumed by `import` and never held by the caller afterwards. Everything else hangs off that handle, grouped by what it does:

| | | returns |
|---|---|---|
| `secret.derive` | `xpub`, `liquidXpub`, `descriptors.bitcoin`, `descriptors.liquid`, `bip85.hex`, `bip85.mnemonic`, `swapKey` | public keys, descriptors, BIP85 children, the swap credential |
| `secret.sign` | `psbt`, `pset`, `psbtSigner` | a signed transaction, or a closable signing capability |
| `secret.backup` | `vault` | a sealed RecoverBull vault |
| `secret.widgets` | `mnemonicView`, `mnemonicChallenge` | the words on screen — never in your hands |
| `secret.verifyWords` | | a verdict |

```dart
await secret.derive.xpub(network: n, scriptType: s);
await secret.sign.psbt(psbt, network: n, scriptType: s);
await secret.backup.vault(metadata: meta);
secret.widgets.mnemonicView(onFailure: (context, failure) => …);
```

Every operation returns `Future<Result<…, SecretFailure>>`, and none returns the stored words. The three that hand back *derived* material — `bip85.hex`, `bip85.mnemonic`, `swapKey` — are the whole list, pinned by a test. Showing the words to the user goes through `secret.widgets`: the widgets read them inside their own state and hand you widgets with no text accessor. Their constructors are `@internal`; the handle is the only way to build them.

## Three things to know before calling

- **⚠️ Passphrase.** Bitcoin derivation and signing honour it. Liquid, the swap key and the vault derive from the words alone — no Liquid wallet supports a passphrase — and say so in the type: those return a `PassphraseScope`, `WordsOnly` when a passphrase exists but took no part. Pass the passphrase back to `Secrets.restoreVault`. The app's default wallets are passphrase-less by rule, and several paths depend on it — see [doc/design.md](doc/design.md), § Passphrase, before allowing one.
- **Failures.** One sealed family, `SecretFailure`. `SecretFetchFailure` is the keystore, `SecretDerivationFailure` is the engine, `SecretStoreLockedFailure` is a sealed keystore — never an absence. Caller misuse is an `ArgumentError`, raised before the boundary.
- **Tests.** `Secrets` and `Secret` are `final`: a double of the custody boundary is a hole in it. Install an in-memory keystore with `package:secrets/testing.dart` and run the real thing. Test-only — an invariant test fails if anything under `lib/` imports it.

## Read next

[doc/design.md](doc/design.md): the contract, the passphrase caveat in full, database keys, the exits, the module layout, how to audit the package, where checks live, rules for contributors, the cohorts whose secrets are not there, and why the package owns the keystore.
