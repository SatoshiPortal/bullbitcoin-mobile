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

`Secrets` is the lifecycle — `generate`, `import`, `fetch`, `list`, `exists`, `idOf`, `trash`, `repairIdentity`, `restoreVault`, and a module's own database key (`databaseKey`, `existingDatabaseKey`, `resetDatabaseKey`). It hands back a `Secret`: a handle that holds no key material, only `info` (identity and shape, safe to log) and `id`, its `Fingerprint`. The words themselves are consumed by `import` and never held by the caller afterwards. Everything else hangs off that handle. This is everything the package can produce from a secret:

| Operation | Returns | Spends? | Privacy |
|---|---|---|---|
| `secret.derive.xpub(network:, scriptType:)` | Bitcoin account xpub | no | sees the whole Bitcoin wallet |
| `secret.derive.liquidXpub(network:, scriptType:)` | Liquid account xpub | no | sees addresses, not blinded amounts |
| `secret.derive.descriptors.bitcoin(network:, scriptType:)` | public descriptors, receive and change | no | as the xpub |
| `secret.derive.descriptors.liquid(network:)` | confidential descriptor, with its SLIP-77 blinding key, as a `PassphraseScope` | no | sees everything, amounts included |
| `secret.sign.psbt(psbt, network:, scriptType:)` | the signed PSBT | that transaction only | public once broadcast |
| `secret.sign.pset(pset, network:)` | the signed PSET | that transaction only | public once broadcast |
| `secret.verifyWords(words)` | `bool` | no | none |
| `secret.info`, `secret.id` | fingerprint and shape | no | none; `info.mnemonicFingerprint` links a passphrase secret to its passphrase-less sibling |
| `secret.derive.bip85.hex(numBytes:, index:)` | BIP85 child entropy | **yes**, over what it controls | secret |
| `secret.derive.bip85.mnemonic(length:, index:)` | BIP85 child words | **yes**, over what it controls | secret |
| `secret.derive.swapKey(network:)` | swap master key: xprv and mnemonic of the BIP85 child 26589 | **yes**, over swaps | secret |
| `secret.backup.vault(metadata:)` | the encrypted file **and** the key that opens it, as a `PassphraseScope` | **yes**: together they are the mnemonic | secret — store them apart |
| `secrets.databaseKey(package:, name:)` | a module's database key | no, but it opens that database | secret |
| `secret.widgets.mnemonicView(…)`, `secret.widgets.mnemonicChallenge(…)` | the words on screen, painted | no — pixels only | what the screen shows |

The stored mnemonic, the passphrase, the seed and the master xprv appear in no row. `Secret.revealMnemonic` is `@internal`, called only by the two widgets. Public outputs — the xpubs and descriptors — are meant to leave: a sync or watch-only module takes them as they are, and treats them as private data.

```dart
await secret.derive.xpub(network: n, scriptType: s);
await secret.sign.psbt(psbt, network: n, scriptType: s);
await secret.backup.vault(metadata: meta);
secret.widgets.mnemonicView(onFailure: (context, failure) => …);
```

Every operation returns `Future<Result<…, SecretFailure>>`, and none returns the stored words. The three that hand back *derived* material — `secret.derive.bip85.hex`, `secret.derive.bip85.mnemonic`, `secret.derive.swapKey` — are the whole list, pinned by a test. Showing the words to the user goes through `secret.widgets`: the widgets read them inside their own state and hand you widgets with no text accessor. Their constructors are `@internal`; the handle is the only way to build them.

## Four things to know before calling

- **⚠️ Passphrase.** Bitcoin derivation and signing and the swap key honour it. Liquid and the vault derive from the words alone — no Liquid wallet supports a passphrase — and say so in the type: `descriptors.liquid` and `backup.vault` return a `PassphraseScope`, `WordsOnly` when a passphrase exists but took no part. Pass the passphrase back to `Secrets.restoreVault`. The app's default wallets are passphrase-less by rule, and several paths depend on it — see [doc/design.md](doc/design.md), § Passphrase, before allowing one.
- **Failures.** One sealed family, `SecretFailure`. `SecretFetchFailure` is the keystore, `SecretDerivationFailure` is the engine, `SecretStoreLockedFailure` is a sealed keystore — never an absence. Caller misuse the package checks — a reserved vault metadata key, a malformed module-key segment — is an `ArgumentError`, raised before the boundary.
- **Signing.** Both chains refuse a PSBT or PSET that asks for anything but `SIGHASH_ALL`: bdk's `allowAllSighashes: false` for Bitcoin, a check in the package before lwk for Liquid. What a transaction pays and to whom is the caller's policy, not the package's.
- **Tests.** `Secrets` and `Secret` are `final`: a double of the custody boundary is a hole in it. Install an in-memory keystore with `package:secrets/testing.dart` and run the real thing. Test-only — an invariant test fails if anything under `lib/` imports it.

## Read next

[doc/design.md](doc/design.md): the contract, the passphrase caveat in full, database keys, the exits, the module layout, how to audit the package, where checks live, rules for contributors, the cohorts whose secrets are not there, and why the package owns the keystore.
