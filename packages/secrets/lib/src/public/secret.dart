import 'package:bip39_mnemonic/bip39_mnemonic.dart'
    show Language, MnemonicLength;
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/data.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/crypto/crypto.dart';

/// An entry found in the keystore, either usable or individually unreadable.
sealed class SecretEntry {
  const SecretEntry._();

  /// Null only when an unreadable entry has no valid fingerprint in its key.
  Fingerprint? get id;
}

/// An entry whose value cannot be read. It exposes no secret operations.
final class UnreadableSecret extends SecretEntry {
  @override
  final Fingerprint? id;
  final SecretFailure failure;

  const UnreadableSecret({this.id, required this.failure}) : super._();

  @override
  String toString() => 'UnreadableSecret($id, ${failure.runtimeType})';
}

/// A stored secret, and everything that can be done with it.
///
/// Obtained from `Secrets` — `generate`, `import` or `fetch` — and holds no key material of its own: [info] describes the secret, and every operation asks the repository to run a closure on material that exists only for that call.
///
/// **This class is the audit surface.** Implementations stay together here behind `@internal`; callers use only the grouped API, such as `secret.sign.psbt(…)`. Its extensions forward calls without handling material or errors. The five implementations that hand back material ([revealMnemonic], [bip85Hex], [bip85Mnemonic], [swapKey], [silentPaymentDescriptors]) can be audited together.
///
/// Nothing here catches: the repository is the boundary that turns an exception into a [SecretFailure].
///
/// A passphrase is honoured by Bitcoin derivation and signing, by the swap key and by the silent payment scan key. Liquid descriptors and signatures use words alone. RecoverBull encrypts only the words, but derives the vault key with the passphrase. See doc/design.md, § Passphrase.
final class Secret extends SecretEntry {
  /// Fingerprint and shape. A plain value: safe to log, to compare, to hold in a bloc state.
  final SecretInfo info;

  final SecretRepository _repository;

  /// The host's scratch directory, which Liquid signing writes under.
  final Future<String> Function() _scratchDirectory;

  /// Built only by [Secrets] — `fetch`, `list`, `generate`, `import`. The parameter types are not exported, but a dot shorthand (`repository: .new()`) would build them from context alone, so the constructor itself is the seal.
  @internal
  const Secret(
    this.info, {
    required this._repository,
    required this._scratchDirectory,
  }) : super._();

  @override
  Fingerprint get id => info.id;

  // ------------------------------------------------------------ derivation

  /// Account-level extended **public** key for a Bitcoin or Liquid wallet. The encoding — xpub/zpub, tpub/vpub — follows from script type and network.
  @internal
  Future<Result<String, SecretFailure>> xpub({
    required Network network,
    required ScriptType scriptType,
    int accountIndex = 0,
  }) {
    _requireIndex(accountIndex, 'accountIndex');
    return _repository.use(
      info,
      (m) => Deriver.bitcoin.xpub(
        m,
        scriptType: scriptType,
        coinType: network.coinType,
        xpubType: scriptType.getXpubType(network),
        accountIndex: accountIndex,
      ),
    );
  }

  /// External and internal public descriptors for a Bitcoin wallet. The master xprv is built and consumed inside the call.
  @internal
  Future<Result<Descriptors, SecretFailure>> bitcoinDescriptors({
    required BitcoinNetwork network,
    required ScriptType scriptType,
    int accountIndex = 0,
  }) {
    _requireIndex(accountIndex, 'accountIndex');
    return _repository.use(
      info,
      (m) => Deriver.bitcoin.descriptors(
        m,
        scriptType: scriptType,
        network: network,
        accountIndex: accountIndex,
      ),
    );
  }

  /// The confidential descriptor, covering both Liquid keychains. lwk derives it from the words, so a seed-only secret is refused from [info] alone.
  ///
  /// ⚠️ **The passphrase is ignored.** lwk derives from the words alone, so the descriptor belongs to the passphrase-less wallet. See doc/design.md, § Passphrase.
  @internal
  Future<Result<String, SecretFailure>> liquidDescriptor({
    required LiquidNetwork network,
  }) => _repository.useMnemonic(
    info,
    (m) => Deriver.liquid.descriptor(m, network: network),
  );

  /// BIP85 child entropy, as hex. The BIP85 root is an xprv, so the derivation stays inside the package; index allocation stays with the caller. No network: BIP85 children are the same on every chain.
  @internal
  Future<Result<String, SecretFailure>> bip85Hex({
    required int numBytes,
    required int index,
  }) {
    _requireIndex(index, 'index');
    if (numBytes < 16 || numBytes > 64) {
      throw ArgumentError('numBytes must be between 16 and 64');
    }
    return _repository.use(
      info,
      (m) => Deriver.bip85.hex(m, numBytes: numBytes, index: index),
    );
  }

  /// BIP85 child mnemonic words. **Returns key material** — a child the caller asked this feature to produce, not the stored secret, so it is not gated behind [RevealReason].
  @internal
  Future<Result<List<String>, SecretFailure>> bip85Mnemonic({
    required MnemonicWordCount wordCount,
    required int index,
    Language language = Language.english,
  }) {
    _requireIndex(index, 'index');
    return _repository.use(
      info,
      (m) => Deriver.bip85.mnemonic(
        m,
        language: language,
        length: MnemonicLength.fromWords(wordCount.count),
        index: index,
      ),
    );
  }

  /// The dedicated swap key for this secret. **Returns key material**, of the same kind as [bip85Mnemonic]: a child the caller stores and uses from then on.
  ///
  /// The passphrase is part of the derivation, so two secrets that share words get different swap keys. Keys stored before that was true were derived from the words alone and are not re-derived — see [BoltzDeriver.swapKey].
  @internal
  Future<Result<SwapMasterKey, SecretFailure>> swapKey({
    required BitcoinNetwork network,
  }) => _repository.useMnemonic(info, (m) async {
    final key = await Deriver.boltz.swapKey(m, network: network);
    log.info('SECRET_DERIVE: swap key for ${info.id}');
    return key;
  });

  /// The BIP352 silent payment scan credential of account 0, as the two descriptors a watch-only bwk account is opened from: `sp(scan private key, spend public key)` and the BIP86 taproot account descriptor. **Returns key material** — a scoped one: it detects incoming silent payments and reveals their amounts, with no spend authority. The spend private key never leaves the package.
  ///
  /// The passphrase is part of the derivation, as for every Bitcoin derivation here. A seed-only secret is refused although BIP352 needs only the seed: the wallet this credential watches must also be spendable, and spending goes through a signer, which takes words. See doc/design.md, § The exits.
  @internal
  Future<Result<SilentPaymentDescriptors, SecretFailure>>
  silentPaymentDescriptors({required BitcoinNetwork network}) =>
      _repository.useMnemonic(info, (m) {
        final key = Deriver.bip352.scanKey(m, network: network);
        log.info('SECRET_DERIVE: silent payment scan key for ${info.id}');
        return key;
      });

  // --------------------------------------------------------------- signing

  /// Signs a PSBT. The mnemonic never crosses this boundary, and the bdk
  /// wallet built to sign is freed before this returns.
  @internal
  Future<Result<String, SecretFailure>> signPsbt(
    String psbt, {
    required BitcoinNetwork network,
    required ScriptType scriptType,
    int accountIndex = 0,
  }) {
    _requireIndex(accountIndex, 'accountIndex');
    return _repository.useMnemonic(
      info,
      (m) => Signer.bitcoin.signPsbt(
        m,
        psbt: psbt,
        scriptType: scriptType,
        network: network,
        accountIndex: accountIndex,
      ),
    );
  }

  /// Signs a PSET.
  ///
  /// ⚠️ **A passphrase is ignored here**, as in [liquidDescriptor] — consistently, which keeps the signature matching the descriptor. See doc/design.md, § Passphrase.
  @internal
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

  // ---------------------------------------------------------------- backup

  /// Seals this secret into a RecoverBull vault and returns its key separately. Store the two apart: together they recover the mnemonic.
  ///
  /// [metadata] is returned by `secrets.recoverbull.restore`; it must not contain a `mnemonic` entry. Each backup derives its key at a fresh random BIP85 index. No network.
  ///
  /// The vault contains only the words, without the passphrase. Its encryption key derives from the original seed, including the passphrase. Restoring a passphrase-protected Bitcoin wallet also requires its passphrase; the app's default wallets never have one.
  @internal
  Future<Result<({EncryptedVault vault, VaultKey key}), SecretFailure>>
  backupRecoverbull({Map<String, dynamic> metadata = const {}}) async {
    _requireNoReservedMetadata(metadata);
    return _repository.useMnemonic(info, (m) {
      final path = Backup.recoverbull.newDerivationPath();
      final key = VaultKey(
        Backup.recoverbull.backupKey(
          masterXprv: Deriver.bip85.root(m),
          path: path,
        ),
      );
      log.info('SECRET_BACKUP: Backup sealed for ${info.id} at $path');
      return (
        vault: EncryptedVault(
          json: Backup.recoverbull.seal(
            words: m.words,
            metadata: metadata,
            backupKey: key.hex,
            derivationPath: path,
          ),
        ),
        key: key,
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
  @internal
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

  /// Compares every seed byte, including the stored passphrase for a mnemonic.
  @internal
  Future<Result<bool, SecretFailure>> verifySeed(String hex) =>
      _repository.use(info, (material) {
        if (hex.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
          return false;
        }
        final seed = material.seedBytes;
        if (hex.length != seed.length * 2) return false;
        var difference = 0;
        for (var i = 0; i < seed.length; i++) {
          difference |=
              seed[i] ^ int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
        }
        return difference == 0;
      });

  static void _requireIndex(int index, String name) {
    if (index < 0 || index > 0x7fffffff) {
      throw ArgumentError.value(
        index,
        name,
        'must be between 0 and 0x7fffffff',
      );
    }
  }

  @override
  String toString() => 'Secret(${info.id.hex})';
}
