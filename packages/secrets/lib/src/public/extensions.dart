import 'package:bip39_mnemonic/bip39_mnemonic.dart'
    show Language, MnemonicLength;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/public/secret.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/crypto/crypto.dart' show Descriptors, PsbtSigner;
import 'package:secrets/src/widgets/widgets.dart' show SecretWidgets;

/// Grouped spelling for [Secret]'s operations.
///
/// `secret.sign.psbt(psbt, …)` instead of `secret.signPsbt(psbt, …)`,
/// and so on. Every member of this file is a **single forwarding
/// expression** to the method of the same meaning on [Secret] — there is
/// no behaviour here, no key material, no error handling, and there must
/// never be any. `test/inertness_test.dart` asserts it: no `await`, no
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
  /// Public keys, descriptors and BIP85 children.
  SecretDerivation get derive => SecretDerivation._(this);

  /// Signatures.
  SecretSigning get sign => SecretSigning._(this);

  /// Sealed backups. Produces ciphertext, never plaintext.
  SecretBackup get backup => SecretBackup._(this);

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
  Future<Result<String, SecretFailure>> xpub({
    required BitcoinNetwork network,
    required ScriptType scriptType,
    int accountIndex = 0,
  }) => _secret.xpub(
    network: network,
    scriptType: scriptType,
    accountIndex: accountIndex,
  );

  /// Account-level extended public key for a Liquid wallet. See [Secret.liquidXpub].
  Future<Result<String, SecretFailure>> liquidXpub({
    required LiquidNetwork network,
    required ScriptType scriptType,
    int accountIndex = 0,
  }) => _secret.liquidXpub(
    network: network,
    scriptType: scriptType,
    accountIndex: accountIndex,
  );

  /// The dedicated swap key. Returns key material.
  ///
  /// ⚠️ Keys stored before the passphrase took part are not re-derived.
  /// See [Secret.swapKey].
  Future<Result<SwapKey, SecretFailure>> swapKey({
    required BitcoinNetwork network,
  }) => _secret.swapKey(network: network);
}

/// Public descriptors for a wallet, per chain.
extension type const SecretDescriptors._(Secret _secret) {
  /// External and internal keychains. See [Secret.bitcoinDescriptors].
  Future<Result<Descriptors, SecretFailure>> bitcoin({
    required BitcoinNetwork network,
    required ScriptType scriptType,
  }) => _secret.bitcoinDescriptors(network: network, scriptType: scriptType);

  /// The confidential descriptor.
  ///
  /// ⚠️ `WordsOnly` when the secret has a passphrase: the descriptor, its
  /// addresses and its funds are the passphrase-less sibling's. See
  /// [Secret.liquidDescriptor].
  Future<Result<PassphraseScope<String>, SecretFailure>> liquid({
    required LiquidNetwork network,
  }) => _secret.liquidDescriptor(network: network);
}

/// BIP85 children.
extension type const SecretBip85._(Secret _secret) {
  /// Child entropy, as hex. See [Secret.bip85Hex].
  Future<Result<String, SecretFailure>> hex({
    required int numBytes,
    required int index,
  }) => _secret.bip85Hex(numBytes: numBytes, index: index);

  /// Child mnemonic words. Returns key material.
  /// See [Secret.bip85Mnemonic].
  Future<Result<List<String>, SecretFailure>> mnemonic({
    required MnemonicLength length,
    required int index,
    Language language = Language.english,
  }) => _secret.bip85Mnemonic(length: length, index: index, language: language);
}

/// Signatures. The mnemonic never crosses this boundary.
extension type const SecretSigning._(Secret _secret) {
  /// Signs a PSBT. See [Secret.signPsbt].
  Future<Result<String, SecretFailure>> psbt(
    String psbt, {
    required BitcoinNetwork network,
    required ScriptType scriptType,
  }) => _secret.signPsbt(psbt, network: network, scriptType: scriptType);

  /// Signs a PSET.
  ///
  /// ⚠️ A passphrase is ignored here, as in the Liquid descriptor. See
  /// [Secret.signPset].
  Future<Result<String, SecretFailure>> pset(
    String pset, {
    required LiquidNetwork network,
  }) => _secret.signPset(pset, network: network);

  /// A reusable signing capability, for payjoin.
  /// See [Secret.psbtSigner].
  Future<Result<PsbtSigner, SecretFailure>> psbtSigner({
    required BitcoinNetwork network,
    required ScriptType scriptType,
  }) => _secret.psbtSigner(network: network, scriptType: scriptType);
}

/// Sealed backups of this secret.
extension type const SecretBackup._(Secret _secret) {
  /// Seals this secret into a RecoverBull vault.
  ///
  /// ⚠️ `WordsOnly` when the secret has a passphrase: the file alone
  /// restores a different wallet. See [Secret.backupVault].
  Future<Result<PassphraseScope<EncryptedVault>, SecretFailure>> vault({
    Map<String, dynamic> metadata = const {},
  }) => _secret.backupVault(metadata: metadata);
}
