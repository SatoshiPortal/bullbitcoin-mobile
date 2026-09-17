import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/exceptions.dart';
import 'package:secrets/src/crypto/signers/signers.dart';
import 'package:secrets/src/domain/domain.dart';

/// Signs a base64 PSBT and returns the signed result.
///
/// Synchronous on purpose: bdk's `sign` and `serialize` are, and the Payjoin receiver hands this callback to a native finalisation step that cannot suspend. A closure that could `await` here would have nowhere to do so.
typedef PsbtSigner = String Function(String psbt);

/// Bitcoin signing through bdk. Reached as `Signer.bitcoin`.
///
/// Builds a wallet the signer owns and throws away. It never touches the
/// app's wallet databases: signing needs the keys and the descriptors,
/// not the transaction history.
///
/// **Every bdk handle this class creates is freed before the call
/// returns.** bdk is UniFFI-generated: each handle owns native memory and
/// carries a `Finalizer`, so nothing leaks — but a finalizer runs when
/// the GC gets to it, and until then an xprv and a private descriptor sit
/// in native memory. `dispose()` is what makes "secrets are ephemeral"
/// true here rather than eventually. `lower()` clones the pointer, so the
/// callee holds its own reference and disposing ours is safe.
///
/// The one handle that outlives a call is the wallet behind
/// [psbtSigner] — see there.
final class BitcoinSigner {
  /// bdk's gap limit when deriving addresses to recognise its own inputs.
  /// Matches `BdkFacade`, so a PSBT this signer accepts is the one the
  /// app's wallet would have accepted.
  static const _lookahead = 25;

  const BitcoinSigner();

  /// Signs one PSBT and frees everything it built.
  ///
  /// The normal path. [psbtSigner] exists for payjoin, which cannot work
  /// this way.
  Future<String> signPsbt(
    MnemonicMaterial secret, {
    required String psbt,
    required ScriptType scriptType,
    required BitcoinNetwork network,
  }) async {
    final wallet = _wallet(secret, scriptType: scriptType, network: network);
    try {
      return _sign(wallet, psbt);
    } finally {
      wallet.dispose();
    }
  }

  /// A closure that signs PSBTs for [secret].
  ///
  /// The wallet is built here and captured by the closure, so a caller
  /// that signs many transactions pays the construction once. The
  /// mnemonic never crosses the returned boundary.
  ///
  /// ⚠️ **The wallet lives as long as the closure**, and it holds private
  /// descriptors in native memory: bdk offers no way to sign repeatedly
  /// without one. Nothing leaks — the handle's finalizer frees it once the
  /// closure is unreachable — but the caller decides how long that is.
  /// Payjoin is the only caller, and it drops the signer with the session.
  Future<PsbtSigner> psbtSigner(
    MnemonicMaterial secret, {
    required ScriptType scriptType,
    required BitcoinNetwork network,
  }) async {
    final wallet = _wallet(secret, scriptType: scriptType, network: network);
    return (String psbt) => _sign(wallet, psbt);
  }

  /// bdk's exceptions do not leave: the closure returned by [psbtSigner]
  /// runs outside any boundary, and bdk's parse error quotes its input.
  static String _sign(bdk.Wallet wallet, String psbt) {
    final bdk.Psbt parsed;
    try {
      parsed = bdk.Psbt(psbtBase64: psbt);
    } on Exception {
      throw const PsbtSigningFailed();
    }
    try {
      final isFinalized = wallet.sign(psbt: parsed, signOptions: _signOptions);
      // Not an error on its own: a payjoin proposal still carries the
      // other party's unsigned inputs, so bdk's whole-PSBT finalization
      // check is false there by protocol design.
      log.fine('Signed PSBT finalized: $isFinalized');
      return parsed.serialize();
    } on Exception {
      throw const PsbtSigningFailed();
    } finally {
      parsed.dispose();
    }
  }

  /// A signing-only bdk wallet, persisted nowhere.
  ///
  /// Built from the BIP39 words rather than from the master xprv, which
  /// mirrors `BdkFacade.createPrivateWallet` exactly. The two paths
  /// should produce identical keys, but a refactor is the wrong place to
  /// find out otherwise: signatures must come out of the same
  /// construction they came out of before.
  ///
  /// The mnemonic, the secret key and the two descriptors are freed here:
  /// the wallet holds its own references, and these would otherwise keep
  /// an xprv in native memory for as long as the wallet.
  bdk.Wallet _wallet(
    MnemonicMaterial secret, {
    required ScriptType scriptType,
    required BitcoinNetwork network,
  }) {
    final networkKind = network.isMainnet
        ? bdk.NetworkKind.main
        : bdk.NetworkKind.test;

    final mnemonic = bdk.Mnemonic.fromString(
      mnemonic: mnemonicSentence(secret),
    );
    final secretKey = bdk.DescriptorSecretKey(
      networkKind: networkKind,
      mnemonic: mnemonic,
      // Empty and absent are the same passphrase to BIP39, but the app
      // has always passed `null` for absent. Keep it.
      password: secret.passphrase.isNotEmpty ? secret.passphrase : null,
    );

    bdk.Descriptor keychain(bdk.KeychainKind kind) => switch (scriptType) {
      ScriptType.bip84 => bdk.Descriptor.newBip84(
        secretKey: secretKey,
        keychainKind: kind,
        networkKind: networkKind,
      ),
      ScriptType.bip49 => bdk.Descriptor.newBip49(
        secretKey: secretKey,
        keychainKind: kind,
        networkKind: networkKind,
      ),
      ScriptType.bip44 => bdk.Descriptor.newBip44(
        secretKey: secretKey,
        keychainKind: kind,
        networkKind: networkKind,
      ),
    };

    final external = keychain(bdk.KeychainKind.external_);
    final internal = keychain(bdk.KeychainKind.internal);
    // Nothing to keep: this wallet exists for the length of one signing
    // session and leaves no file behind.
    final persister = bdk.Persister.newInMemory();
    try {
      return bdk.Wallet(
        descriptor: external,
        changeDescriptor: internal,
        network: switch (network) {
          BitcoinNetwork.mainnet => bdk.Network.bitcoin,
          BitcoinNetwork.testnet => bdk.Network.testnet,
          BitcoinNetwork.signet => bdk.Network.signet,
          BitcoinNetwork.regtest => bdk.Network.regtest,
        },
        persister: persister,
        lookahead: _lookahead,
      );
    } finally {
      // The persister holds no key, but the class doc promises every handle
      // is freed, and a promise with one exception is not one.
      persister.dispose();
      external.dispose();
      internal.dispose();
      secretKey.dispose();
      mnemonic.dispose();
    }
  }

  /// Mirrors `BdkWalletDatasource.signPsbt` exactly: a refactor must not
  /// change how signatures are produced.
  static final _signOptions = bdk.SignOptions(
    trustWitnessUtxo: true,
    assumeHeight: null,
    // The signer contributes its own inputs under the sighash the
    // transaction specifies; accepting any sighash would let a
    // counterparty choose one.
    allowAllSighashes: false,
    tryFinalize: true,
    signWithTapInternalKey: false,
    allowGrinding: true,
  );
}
