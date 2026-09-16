import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/exceptions.dart';
import 'package:secrets/src/crypto/signers/signers.dart';
import 'package:secrets/src/domain/domain.dart';

/// Liquid signing through lwk. Reached as `Signer.liquid`.
///
/// One-shot, unlike [BitcoinSigner]: lwk gives no reason to hold a
/// wallet open — `signTx` takes the mnemonic again at call time, so the
/// wallet built by `Wallet.init` holds no key worth reusing.
///
/// The lwk wallet is `dispose()`d before the call returns: it is a
/// flutter_rust_bridge opaque, so its `Arc` would otherwise be released
/// whenever the GC got to it. The scratch directory goes the same way —
/// see [signPset].
///
/// ⚠️ A passphrase is ignored. lwk's signer hard-codes `to_seed("")`
/// and no layer of the binding takes one. See the README, § Passphrase.
final class LiquidSigner {
  const LiquidSigner();

  /// Signs one PSET and returns it.
  ///
  /// [scratchDirectory] is where lwk may write its scratch wallet cache
  /// for the length of this call. lwk has no in-memory persister —
  /// `Wallet.init` requires a path — so the host supplies a directory
  /// rather than this package reaching for `path_provider`. It is a
  /// parameter of the operation, not of the signer: each call creates
  /// and removes its own directory beneath it, and keeping this type
  /// field-free is what lets it sit on the [Signer] namespace like the
  /// others. It goes away the day lwk-dart binds `SwSigner` directly.
  Future<String> signPset(
    MnemonicMaterial secret, {
    required String pset,
    required LiquidNetwork network,
    required Future<String> Function() scratchDirectory,
  }) async {
    final mnemonic = mnemonicSentence(secret);
    final lwkNetwork = _network(network);

    // A fresh directory per signature, removed below.
    //
    // lwk has no in-memory persister, so a database gets created whether
    // we want one or not. Keeping it would leave a confidential
    // descriptor on disk in an unencrypted file, outside the keystore
    // this package exists to keep things inside — and name it after a
    // wallet fingerprint while we were at it. A temporary directory
    // costs one wallet construction per signature and leaves nothing.
    final scratch = await Directory(
      await scratchDirectory(),
    ).createTemp('lwk_sign_');

    lwk.Wallet? wallet;
    try {
      wallet = await lwk.Wallet.init(
        network: lwkNetwork,
        dbpath: scratch.path,
        descriptor: await lwk.Descriptor.newConfidential(
          network: lwkNetwork,
          mnemonic: mnemonic,
        ),
      );
      return await wallet.signTx(
        network: lwkNetwork,
        pset: pset,
        mnemonic: mnemonic,
      );
    } on lwk.LwkError {
      // `e.msg` is lwk's text and is not logged: the input is a PSET and a mnemonic, and no rule keeps a foreign message from quoting either. The boundary reports the type.
      throw const LiquidSigningFailed();
    } finally {
      // An FRB opaque holding the wallet's `Arc`; `Descriptor` is a plain
      // value and has no handle to release.
      wallet?.dispose();
      try {
        await scratch.delete(recursive: true);
      } catch (e) {
        // A leftover only happens if deletion itself fails; a hard crash
        // mid-signature can also leave one. Worth knowing about, not
        // worth failing a signature over.
        log.warning('Could not remove lwk scratch directory: $e');
      }
    }
  }

  static lwk.LiquidNetwork _network(LiquidNetwork network) => switch (network) {
    LiquidNetwork.mainnet => lwk.LiquidNetwork.mainnet,
    LiquidNetwork.testnet => lwk.LiquidNetwork.testnet,
    // Elements regtest is a different chain; lwk has no variant for
    // it, and signing on testnet's would produce a signature for the
    // wrong chain. See `SecretDeriver.liquidDescriptor`.
    LiquidNetwork.regtest => throw const UnsupportedLiquidNetwork(
      'lwk cannot express Liquid regtest',
    ),
  };
}
