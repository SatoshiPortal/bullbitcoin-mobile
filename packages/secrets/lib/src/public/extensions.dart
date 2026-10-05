import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/public/secret.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/crypto/crypto.dart' show Descriptors;
import 'package:secrets/src/widgets/widgets.dart' show SecretWidgets;

/// Grouped spelling for [Secret]'s operations.
///
/// `secret.sign.psbt(psbt, …)` instead of `secret.signPsbt(psbt, …)`,
/// and so on. Every member of this file is a **single forwarding
/// expression** to the method of the same meaning on [Secret] — there is
/// no behaviour here, no key material, no error handling, and there must
/// never be any. `test/invariants_test.dart` asserts it: no `await`, no
/// `guard`, no reference to the repository, the deriver, the signer or
/// `SecretMaterial`, and one expression per member.
///
/// That is what keeps [Secret] the whole audit surface: this file cannot
/// add an operation, and cannot change what one does.
///
/// The wrappers are `extension type`s, so they erase at compile time —
/// `secret.sign.psbt(…)` allocates nothing and costs no indirection.
///
/// Documentation lives on [Secret], where the behaviour is. Each member
/// below carries only its one-line summary, any ⚠️ that must not be
/// missed, and a link to the real doc.
extension SecretExtension on Secret {
  /// Public keys, descriptors, BIP85 children and scoped credentials.
  SecretDerivation get derive => SecretDerivation._(this);

  /// Signatures.
  SecretSigning get sign => SecretSigning._(this);

  /// Sealed backups. Produces ciphertext, never plaintext.
  SecretBackup get backup => SecretBackup._(this);

  /// Compares user input without revealing the stored words or seed.
  SecretVerification get verify => SecretVerification._(this);

  /// The sealed widgets: the words on screen, never in the caller's hands.
  SecretWidgets get widgets => SecretWidgets(this);
}

/// Everything that derives *from* a secret.
extension type const SecretDerivation._(Secret _secret) {
  /// Public descriptors, per chain.
  SecretDescriptors get descriptors => SecretDescriptors._(_secret);

  /// BIP85 children of this secret.
  SecretBip85 get bip85 => SecretBip85._(_secret);

  /// Account-level extended public key. See [Secret.xpub].
  @useResult
  Future<Result<String, SecretFailure>> xpub({
    required Network network,
    required ScriptType scriptType,
    int accountIndex = 0,
  }) => _secret.xpub(
    network: network,
    scriptType: scriptType,
    accountIndex: accountIndex,
  );

  /// The dedicated swap key. Returns key material.
  ///
  /// ⚠️ Keys stored before the passphrase took part are not re-derived.
  /// See [Secret.swapKey].
  @useResult
  Future<Result<SwapMasterKey, SecretFailure>> swapKey({
    required BitcoinNetwork network,
  }) => _secret.swapKey(network: network);
}

/// Descriptors for a wallet, per chain. All are public except
/// [silentPayment]'s `sp` descriptor, which carries the BIP352 scan private key.
extension type const SecretDescriptors._(Secret _secret) {
  /// External and internal keychains. See [Secret.bitcoinDescriptors].
  @useResult
  Future<Result<Descriptors, SecretFailure>> bitcoin({
    required BitcoinNetwork network,
    required ScriptType scriptType,
    int accountIndex = 0,
  }) => _secret.bitcoinDescriptors(
    network: network,
    scriptType: scriptType,
    accountIndex: accountIndex,
  );

  /// The confidential descriptor.
  ///
  /// The passphrase is ignored. See [Secret.liquidDescriptor].
  @useResult
  Future<Result<String, SecretFailure>> liquid({
    required LiquidNetwork network,
  }) => _secret.liquidDescriptor(network: network);

  /// The two descriptors a watch-only BIP352 silent payment account is
  /// opened from. Returns key material: `sp` reveals incoming payments, it
  /// cannot spend. See [Secret.silentPaymentDescriptors].
  @useResult
  Future<Result<SilentPaymentDescriptors, SecretFailure>> silentPayment({
    required BitcoinNetwork network,
  }) => _secret.silentPaymentDescriptors(network: network);
}

/// BIP85 children.
extension type const SecretBip85._(Secret _secret) {
  /// Child entropy, as hex. See [Secret.bip85Hex].
  @useResult
  Future<Result<String, SecretFailure>> hex({
    required int numBytes,
    required int index,
  }) => _secret.bip85Hex(numBytes: numBytes, index: index);

  /// Child mnemonic words. Returns key material.
  /// See [Secret.bip85Mnemonic].
  @useResult
  Future<Result<List<String>, SecretFailure>> mnemonic({
    required MnemonicWordCount wordCount,
    required int index,
    Language language = Language.english,
  }) => _secret.bip85Mnemonic(
    wordCount: wordCount,
    index: index,
    language: language,
  );
}

/// Signatures. The mnemonic never crosses this boundary.
extension type const SecretSigning._(Secret _secret) {
  /// Signs a PSBT. See [Secret.signPsbt].
  @useResult
  Future<Result<String, SecretFailure>> psbt(
    String psbt, {
    required BitcoinNetwork network,
    required ScriptType scriptType,
    int accountIndex = 0,
  }) => _secret.signPsbt(
    psbt,
    network: network,
    scriptType: scriptType,
    accountIndex: accountIndex,
  );

  /// Signs a PSET.
  ///
  /// ⚠️ A passphrase is ignored here, as in the Liquid descriptor. See
  /// [Secret.signPset].
  @useResult
  Future<Result<String, SecretFailure>> pset(
    String pset, {
    required LiquidNetwork network,
  }) => _secret.signPset(pset, network: network);
}

/// Verdicts only: comparison never hands the stored material to the caller.
extension type const SecretVerification._(Secret _secret) {
  /// Compares words only. A raw seed returns [MnemonicRequiredFailure].
  @useResult
  Future<Result<bool, SecretFailure>> mnemonic(List<String> words) =>
      _secret.verifyWords(words);

  /// Compares full seed bytes encoded as hex, including the stored mnemonic's passphrase. Invalid hex is a mismatch.
  @useResult
  Future<Result<bool, SecretFailure>> seed(String hex) =>
      _secret.verifySeed(hex);
}

/// Sealed backups of this secret.
extension type const SecretBackup._(Secret _secret) {
  /// Seals words into a RecoverBull vault. Its key derivation honours the passphrase; the payload does not include it. Keep the returned key apart from the vault. See [Secret.backupRecoverbull].
  @useResult
  Future<Result<({EncryptedVault vault, VaultKey key}), SecretFailure>>
  recoverbull({Map<String, dynamic> metadata = const {}}) =>
      _secret.backupRecoverbull(metadata: metadata);
}
