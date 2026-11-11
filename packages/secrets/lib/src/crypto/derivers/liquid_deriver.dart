import 'dart:typed_data';

import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/derivers/derivers.dart';
import 'package:secrets/src/crypto/exceptions.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:meta/meta.dart';

/// Liquid derivations through lwk. Reached as `Deriver.liquid`.
///
/// Takes [Mnemonic], never a bare `SecretMaterial`: the Liquid wallet is
/// the passphrase-less seed of the words (see [liquidSeed]), which a
/// seed-only secret cannot give, so the type refuses it before anything is
/// computed.
final class LiquidDeriver {
  @internal
  const LiquidDeriver();

  /// The confidential descriptor, which covers both keychains.
  ///
  /// ⚠️ **A passphrase takes no part**: see [liquidSeed]. A passphrase
  /// secret gets its passphrase-less sibling's descriptor — same addresses,
  /// same funds. See doc/design.md, § Passphrase.
  ///
  /// Regtest is refused rather than folded into testnet: Elements
  /// regtest is a different chain, and a confidential descriptor built
  /// for testnet would hand back addresses that do not belong to it.
  Future<String> descriptor(
    Mnemonic secret, {
    required LiquidNetwork network,
  }) async {
    final lwkNetwork = switch (network) {
      LiquidNetwork.mainnet => lwk.LiquidNetwork.mainnet,
      LiquidNetwork.testnet => lwk.LiquidNetwork.testnet,
      LiquidNetwork.regtest => throw const UnsupportedLiquidNetwork(
        'lwk cannot express Liquid regtest',
      ),
    };
    final seed = liquidSeed(secret);
    try {
      final descriptor = await lwk.Descriptor.newConfidentialFromSeed(
        network: lwkNetwork,
        seed: seed,
      );
      // A plain value, not an FRB opaque: `Descriptor` is one `String`
      // field, so there is no native handle to release here.
      return descriptor.ctDescriptor;
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
  }
}

/// The seed every Liquid wallet of [secret] derives from: the BIP39 seed of
/// its words in its own language, **without** its passphrase.
///
/// The words' language takes part, so a mnemonic in any BIP39 language gets
/// its own wallet; an English one gets exactly the descriptor lwk derived
/// from its words. The passphrase does not, on purpose: lwk's word-based
/// signer always used `to_seed("")`, so every Liquid wallet of a passphrase
/// secret, and the funds on it, lives on the passphrase-less seed. Honouring
/// the passphrase would move those wallets. See doc/design.md, § Passphrase.
///
/// A fresh buffer each call: the caller wipes it once lwk has it.
@internal
Uint8List liquidSeed(Mnemonic secret) =>
    Deriver.fingerprint.seed(secret.words, language: secret.language);
