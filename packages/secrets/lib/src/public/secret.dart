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
/// **This class is the audit surface.** Implementations stay together here behind `@internal`; callers use only the grouped API, such as `secret.sign.psbt(…)`. Its extensions forward calls without handling material or errors. The four implementations that hand back material ([revealMnemonic], [bip85Hex], [bip85Mnemonic], [swapKey]) can be audited together.
///
/// Nothing here catches: the repository is the boundary that turns an exception into a [SecretFailure].
///
/// A passphrase is honoured by Bitcoin and Liquid derivation and signing and by the swap key. RecoverBull encrypts only the words, but derives the vault key with the passphrase. See doc/design.md, § Passphrase.
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

  /// Public key and actual root fingerprint at an explicit BIP32 path.
  /// An omitted passphrase uses the stored one; an empty override uses words alone.
  @internal
  Future<Result<PublicAccountKey, SecretFailure>> account({
    required String derivationPath,
    required BitcoinNetwork network,
    String? passphrase,
  }) => _repository.use(
    info,
    (material) => Deriver.bitcoin.account(
      material,
      derivationPath: derivationPath,
      network: network,
      passphrase: passphrase,
    ),
  );

  /// Adds signatures for the selected public descriptor keys without finalizing.
  /// Private descriptors and native signing handles exist only inside this call.
  @internal
  Future<Result<String, SecretFailure>> signDescriptorPsbt(
    String psbt, {
    required String descriptor,
    required BitcoinNetwork network,
    required List<DescriptorSigningKey> keys,
    String? passphrase,
    bool signWithTapInternalKey = false,
  }) {
    final selected = List<DescriptorSigningKey>.of(keys);
    return _repository.use(
      info,
      (material) => Signer.bitcoin.signDescriptorPsbt(
        material,
        psbt: psbt,
        descriptor: descriptor,
        network: network,
        keys: selected,
        passphrase: passphrase,
        signWithTapInternalKey: signWithTapInternalKey,
      ),
    );
  }

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

  /// The confidential descriptor, covering both Liquid keychains, from the secret's full BIP39 seed (passphrase included). A seed-only secret is refused from [info] alone.
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
    required MnemonicLength wordCount,
    required int index,
    Language language = Language.english,
  }) {
    _requireIndex(index, 'index');
    return _repository.use(
      info,
      (m) => Deriver.bip85.mnemonic(
        m,
        language: language,
        length: wordCount,
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

  // ------------------------------------------------------- silent payments

  /// Opens this secret's Silent Payments account (BIP352, account 0) in bwk, which scans and signs for it while the returned account lives. The caller owns it and disposes it when the session ends.
  ///
  /// ⚠️ **The words reach bwk.** bwk-dart opens an account from a mnemonic only, and its returned account retains keys after this call; they never reach the app, and the account holds the keys until it is disposed.
  ///
  /// ⚠️ **A passphrase cannot be honoured** — bwk derives from the words alone — so a secret that has one is refused with `PassphraseUnsupportedFailure` rather than opening the passphrase-less sibling's wallet.
  @internal
  Future<Result<SpAccount, SecretFailure>> silentPaymentsAccount({
    required String name,
    required SpNetwork network,
    required String blindbitUrl,
    required String electrumUrl,
    required String dataDir,
    required BigInt dustLimit,
    required int fetchConcurrencyFactor,
    required int matchConcurrencyFactor,
    SpHeaderCheckpoint? headerCheckpoint,
  }) => _repository.useMnemonic(
    info,
    (m) => SilentPayments.open(
      m,
      name: name,
      network: network,
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
      dataDir: dataDir,
      dustLimit: dustLimit,
      fetchConcurrencyFactor: fetchConcurrencyFactor,
      matchConcurrencyFactor: matchConcurrencyFactor,
      headerCheckpoint: headerCheckpoint,
    ),
  );

  // ---------------------------------------------------------------- backup

  /// Seals this secret into a RecoverBull vault and returns its key separately. Store the two apart: together they recover the mnemonic.
  ///
  /// [metadata] is returned by `secrets.recoverbull.restore`; it must not contain `mnemonic` or `mnemonicLanguage` entries; `language` stays free for the caller. Each backup derives its key at a fresh random BIP85 index. No network.
  ///
  /// The vault contains the words and their language, without the passphrase. Its encryption key derives from the original seed, including the passphrase. Restoring a passphrase-protected Bitcoin wallet also requires its passphrase; the app's default wallets never have one.
  @internal
  Future<Result<({EncryptedVault vault, VaultKey key}), SecretFailure>>
  backupRecoverbull({Map<String, dynamic> metadata = const {}}) async {
    // The repository awaits the keystore. Freeze the validated top-level
    // fields so the caller cannot inject a reserved key before sealing ends.
    final snapshot = Map<String, dynamic>.unmodifiable(metadata);
    _requireNoReservedMetadata(snapshot);
    return _repository.useMnemonic(info, (m) {
      final path = Backup.recoverbull.newDerivationPath();
      final key = VaultKey(
        Backup.recoverbull.backupKey(
          masterXprv: Deriver.bip85.root(m),
          path: path,
        ),
      );
      log.fine('secret.backup.sealed');
      return (
        vault: EncryptedVault(
          json: Backup.recoverbull.seal(
            words: m.words,
            language: m.language,
            metadata: snapshot,
            backupKey: key.hex,
            derivationPath: path,
          ),
        ),
        key: key,
      );
    });
  }

  /// Returns the recorded vault's key only after it opens a valid mnemonic payload. The stored passphrase participates in derivation; no words or private keys leave this call.
  @internal
  Future<Result<VaultKey, SecretFailure>> recoverbullKey({
    required EncryptedVault vault,
  }) => _repository.useMnemonic(
    info,
    (m) => VaultKey(
      Backup.recoverbull.verifiedKey(
        masterXprv: Deriver.bip85.root(m),
        file: vault.json,
      ),
    ),
  );

  /// Caller misuse is an [ArgumentError], raised *before* the boundary: the
  /// caller then reads this package's own message, not a redacted type name.
  /// Inside the boundary an `Error` is a bug and leaves with its type only.
  static void _requireNoReservedMetadata(Map<String, dynamic> metadata) {
    final reserved = Backup.recoverbull.reservedMetadataKeys;
    for (final key in metadata.keys) {
      if (reserved.contains(key)) {
        throw ArgumentError.value(
          key,
          'metadata',
          'the mnemonic is written by the vault, not by the caller',
        );
      }
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
    return RevealedMnemonic(
      words: m.words,
      language: m.language,
      passphrase: m.passphrase,
    );
  });

  /// Compares user-typed words against the stored ones without exposing either.
  @internal
  Future<Result<bool, SecretFailure>> verifyWords(List<String> words) {
    // Copied now: the comparison runs after the secret has loaded, and a
    // caller that reuses its list in between must not change the verdict.
    final candidate = Deriver.fingerprint.normalizeWords(words);
    return _repository.useMnemonic(info, (m) {
      if (m.words.length != candidate.length) return false;
      final stored = Deriver.fingerprint.normalizeWords(m.words);
      var match = true;
      // No early exit: the loop's duration must not depend on where the first wrong word is.
      for (var i = 0; i < candidate.length; i++) {
        if (stored[i] != candidate[i]) match = false;
      }
      return match;
    });
  }

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
