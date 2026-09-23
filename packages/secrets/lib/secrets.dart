/// User secret material — BIP39 mnemonics and raw seeds — behind a custody boundary.
///
/// One entry point. [Secrets] is the lifecycle — `generate`, `import`, `fetch`, `list`, `trash`, `restoreVault`, `databaseKey` — and hands back a [Secret], a handle that holds no key material. Everything you can do hangs off that handle, grouped by what it does:
///
/// - `secret.derive` — `xpub`, `liquidXpub`, `descriptors.bitcoin`, `descriptors.liquid`, `bip85.hex`, `bip85.mnemonic`, `swapKey`
/// - `secret.sign` — `psbt`, `pset`
/// - `secret.backup` — `vault`
/// - `secret.widgets` — `mnemonicView`, `mnemonicChallenge`: the words on screen, never in the caller's hands
/// - `secret.verifyWords` — a verdict
///
/// A secret is created once — [Secrets.generate], or [Secrets.import] from the user's words — and known from then on by its `Fingerprint`: the BIP32 master fingerprint, eight hex characters, derived from the words and the passphrase. The fingerprint is the only thing a caller keeps; it is safe to log and to store, and every later call takes it.
///
/// ```dart
/// final created = await secrets.generate();
/// final id = ok(created).id;                 // keep this, nothing else
///
/// final secret = switch (await secrets.fetch(id)) {
///   Ok(:final value) => value,
///   Err(:final failure) => return failure,
/// };
/// await secret.derive.xpub(network: n, scriptType: s);
/// await secret.sign.psbt(psbt, network: n, scriptType: s);
/// secret.widgets.mnemonicView(onFailure: (context, failure) => …);
/// ```
///
/// Every operation returns `Future<Result<…, SecretFailure>>` and none returns the stored words; the three that hand back derived material — `bip85.hex`, `bip85.mnemonic`, `swapKey` — are the whole list. ⚠️ Liquid, the swap key and the vault derive from the words alone: those return a [PassphraseScope]. The README is the short version of this; `doc/design.md` holds the contract and how to audit it.
///
/// This file *is* the surface: explicit `show` lists, so what is public is decided here and nowhere else. The failures a caller handles come through `types.dart`, the sealed widgets through `widgets.dart`; the invariant test pins the exact set of names.
library;

export 'src/public/extensions.dart'
    show
        SecretBackup,
        SecretBip85,
        SecretDerivation,
        SecretDescriptors,
        SecretExtension,
        SecretSigning;
export 'src/public/secret.dart' show Secret;
export 'src/public/secrets.dart' show RestoredVault, Secrets;
export 'src/public/types.dart';
export 'src/public/widgets.dart';
