import 'package:bip39_mnemonic/bip39_mnemonic.dart'
    show Language, MnemonicLength;
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/data.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/crypto/crypto.dart';

/// A stored secret, and everything that can be done with it.
///
/// Obtained from `Secrets` — `generate`, `import` or `fetch` — and holds no key material of its own: [info] describes the secret, and every operation asks the repository to run a closure on material that exists only for that call.
///
/// **This class is the audit surface.** Every operation the package can perform on a secret is a method here, flat, in one file — so the four that hand back material ([revealMnemonic], [bip85Hex], [bip85Mnemonic], [swapKey]) are read in the same pass as the ones that do not. The grouped spelling — `secret.sign.psbt(…)` — is sugar over these methods and holds no behaviour; see `extensions.dart`, whose inertness a test asserts.
///
/// Nothing here catches: the repository is the boundary that turns an exception into a [SecretFailure].
///
/// ⚠️ A passphrase is honoured by Bitcoin derivation and signing only. Liquid, the swap key and the Backup derive from the words alone, with no warning at runtime. See the README, § Passphrase.
final class Secret {
  /// Identity and shape. A plain value: safe to log, to compare, to hold in a bloc state.
  final SecretInfo info;

  final SecretRepository _repository;

  /// The host's scratch directory, which Liquid signing writes under.
  final Future<String> Function() _scratchDirectory;

  const Secret(
    this.info, {
    required this._repository,
    required this._scratchDirectory,
  });

  Fingerprint get id => info.id;

  // ------------------------------------------------------------ derivation

  /// Account-level extended **public** key for a Bitcoin wallet. The encoding — xpub/zpub, tpub/vpub — follows from script type and network.
  Future<Result<String, SecretFailure>> xpub({
    required BitcoinNetwork network,
    required ScriptType scriptType,
    int accountIndex = 0,
  }) => _repository.use(
    info,
    (m) => Deriver.bitcoin.xpub(
      m,
      scriptType: scriptType,
      coinType: network.coinType,
      xpubType: scriptType.getXpubType(network),
      accountIndex: accountIndex,
    ),
  );

  /// Account-level extended **public** key for a Liquid wallet: same path shape as [xpub] with Liquid's SLIP-44 coin type (1776 on mainnet, 1 elsewhere), which every Liquid wallet already on a device was derived with.
  Future<Result<String, SecretFailure>> liquidXpub({
    required LiquidNetwork network,
    required ScriptType scriptType,
    int accountIndex = 0,
  }) => _repository.use(
    info,
    (m) => Deriver.bitcoin.xpub(
      m,
      scriptType: scriptType,
      coinType: network.coinType,
      xpubType: scriptType.getXpubType(
        network.isMainnet ? BitcoinNetwork.mainnet : BitcoinNetwork.testnet,
      ),
      accountIndex: accountIndex,
    ),
  );

  /// External and internal public descriptors for a Bitcoin wallet. The master xprv is built and consumed inside the call.
  Future<Result<Descriptors, SecretFailure>> bitcoinDescriptors({
    required BitcoinNetwork network,
    required ScriptType scriptType,
  }) => _repository.use(
    info,
    (m) => Deriver.bitcoin.descriptors(
      m,
      scriptType: scriptType,
      network: network,
    ),
  );

  /// The confidential descriptor, covering both Liquid keychains. lwk derives it from the words, so a seed-only secret is refused from [info] alone.
  ///
  /// ⚠️ **A passphrase takes no part here** — lwk derives from the words alone, at every layer. So the result is a [WordsOnly] for a secret that has one: the descriptor, its addresses and its funds are the passphrase-less sibling's. See the README, § Passphrase.
  Future<Result<PassphraseScope<String>, SecretFailure>> liquidDescriptor({
    required LiquidNetwork network,
  }) => _repository.useMnemonic(
    info,
    (m) async =>
        info.scope(await Deriver.liquid.descriptor(m, network: network)),
  );

  /// BIP85 child entropy, as hex. The BIP85 root is an xprv, so the derivation stays inside the package; index allocation stays with the caller. No network: BIP85 children are the same on every chain.
  Future<Result<String, SecretFailure>> bip85Hex({
    required int numBytes,
    required int index,
  }) => _repository.use(
    info,
    (m) => Deriver.bip85.hex(m, numBytes: numBytes, index: index),
  );

  /// BIP85 child mnemonic words. **Returns key material** — a child the caller asked this feature to produce, not the stored secret, so it is not gated behind [RevealReason].
  Future<Result<List<String>, SecretFailure>> bip85Mnemonic({
    required MnemonicLength length,
    required int index,
    Language language = Language.english,
  }) => _repository.use(
    info,
    (m) => Deriver.bip85.mnemonic(
      m,
      language: language,
      length: length,
      index: index,
    ),
  );

  /// The dedicated swap key for this secret. **Returns key material**, of the same kind as [bip85Mnemonic]: a child the caller stores and uses from then on.
  ///
  /// The passphrase is part of the derivation, so two secrets that share words get different swap keys. Keys stored before that was true were derived from the words alone and are not re-derived — see [BoltzDeriver.swapKey].
  Future<Result<SwapKey, SecretFailure>> swapKey({
    required BitcoinNetwork network,
  }) => _repository.useMnemonic(info, (m) async {
    final key = await Deriver.boltz.swapKey(m, network: network);
    log.info('SECRET_DERIVE: swap key for ${info.id}');
    return key;
  });

  // --------------------------------------------------------------- signing

  /// Signs a PSBT. The mnemonic never crosses this boundary, and the bdk
  /// wallet built to sign is freed before this returns.
  Future<Result<String, SecretFailure>> signPsbt(
    String psbt, {
    required BitcoinNetwork network,
    required ScriptType scriptType,
  }) => _repository.useMnemonic(
    info,
    (m) => Signer.bitcoin.signPsbt(
      m,
      psbt: psbt,
      scriptType: scriptType,
      network: network,
    ),
  );

  /// Signs a PSET.
  ///
  /// ⚠️ **A passphrase is ignored here**, as in [liquidDescriptor] — consistently, which keeps the signature matching the descriptor. See the README, § Passphrase.
  Future<Result<String, SecretFailure>> signPset(
    String pset, {
    required LiquidNetwork network,
  }) => _repository.useMnemonic(
    info,
    (m) => Signer.liquid.signPset(
      m,
      pset: pset,
      network: network,
      scratchDirectory: _scratchDirectory,
    ),
  );

  /// A reusable signing capability, for payjoin, which hands a signer to the protocol layer rather than calling it once. The closure captures a built wallet; the caller never holds the mnemonic.
  Future<Result<PsbtSigner, SecretFailure>> psbtSigner({
    required BitcoinNetwork network,
    required ScriptType scriptType,
  }) => _repository.useMnemonic(
    info,
    (m) =>
        Signer.bitcoin.psbtSigner(m, scriptType: scriptType, network: network),
  );

  // ---------------------------------------------------------------- backup

  /// Seals this secret into a RecoverBull vault. Not a reveal: what comes back is ciphertext plus the key that opens it — hold both and you hold the mnemonic, so store them apart.
  ///
  /// [metadata] is whatever the caller wants back from `Secrets.restoreVault`; it must not carry a `mnemonic` entry. The backup key is derived at a fresh random BIP85 index each time. No network.
  ///
  /// ⚠️ **The passphrase is not in the file.** The format carries the words alone — the one every existing Backup and the key server speak — so this returns a [WordsOnly] for a secret that has a passphrase: restoring the file alone gives a different Bitcoin wallet. Tell the user to keep the passphrase with the backup, and pass it back to `Secrets.restoreVault`. See the README, § Passphrase.
  Future<Result<PassphraseScope<EncryptedVault>, SecretFailure>> backupVault({
    Map<String, dynamic> metadata = const {},
  }) async {
    // `async`, so caller misuse rejects the Future as it always did rather
    // than throwing at the call site.
    _requireNoReservedMetadata(metadata);
    return _repository.useMnemonic(info, (m) {
      final path = Backup.recoverbull.newDerivationPath();
      final key = Backup.recoverbull.backupKey(
        masterXprv: Deriver.bip85.root(m),
        path: path,
      );
      log.info('SECRET_BACKUP: Backup sealed for ${info.id} at $path');
      return info.scope(
        EncryptedVault(
          file: Backup.recoverbull.seal(
            words: m.words,
            metadata: metadata,
            backupKey: key,
            derivationPath: path,
          ),
          key: key,
          derivationPath: path,
        ),
      );
    });
  }

  /// Caller misuse is an [ArgumentError], raised *before* the boundary: the
  /// caller then reads this package's own message, not a redacted type name.
  /// Inside the boundary an `Error` is a bug and leaves with its type only.
  static void _requireNoReservedMetadata(Map<String, dynamic> metadata) {
    final reserved = Backup.recoverbull.reservedMetadataKey;
    if (metadata.containsKey(reserved)) {
      throw ArgumentError.value(
        reserved,
        'metadata',
        'the mnemonic is written by the vault, not by the caller',
      );
    }
  }

  // ---------------------------------------------------------------- reveal

  /// Hands back the mnemonic in clear — words and passphrase both. **Returns the stored secret itself**; everything else here returns something derived, or ciphertext. Logged.
  ///
  /// `@internal`: the only callers are this package's own sealed widgets,
  /// `MnemonicView` and `MnemonicChallenge`. A feature that reaches for it
  /// gets an `invalid_use_of_internal_member` error, which is the point —
  /// showing words to a user is a display concern, and a display that hands
  /// them back to the caller has nothing left to seal. To compare words, use
  /// [verifyWords]: same answer, nothing exposed.
  @internal
  Future<Result<RevealedMnemonic, SecretFailure>> revealMnemonic({
    required RevealReason reason,
  }) => _repository.useMnemonic(info, (m) {
    log.info('SECRET_REVEAL: mnemonic for ${info.id} (${reason.name})');
    return RevealedMnemonic(words: m.words, passphrase: m.passphrase);
  });

  /// Compares user-typed words against the stored ones without exposing either.
  Future<Result<bool, SecretFailure>> verifyWords(
    List<String> candidate,
  ) => _repository.useMnemonic(info, (m) {
    if (m.words.length != candidate.length) return false;
    var match = true;
    // No early exit: the loop's duration must not depend on where the first wrong word is.
    for (var i = 0; i < candidate.length; i++) {
      if (m.words[i] != candidate[i]) match = false;
    }
    return match;
  });

  @override
  String toString() => 'Secret(${info.id.hex})';
}
