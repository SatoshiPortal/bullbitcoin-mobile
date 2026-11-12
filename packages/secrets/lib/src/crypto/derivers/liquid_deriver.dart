import 'dart:typed_data';

import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:meta/meta.dart';

/// Liquid derivations through lwk. Reached as `Deriver.liquid`.
///
/// Takes [Mnemonic], never a bare `SecretMaterial`: a seed-only secret
/// is a historical entry Liquid never derived from, so the type refuses it
/// before anything is computed.
final class LiquidDeriver {
  @internal
  const LiquidDeriver();

  /// The confidential descriptor, which covers both keychains.
  ///
  /// The passphrase takes part: see [liquidSeed].
  ///
  /// Each network maps to lwk's own, regtest included: Elements regtest is
  /// a chain of its own, never folded into testnet.
  Future<String> descriptor(
    Mnemonic secret, {
    required LiquidNetwork network,
  }) async {
    final lwkNetwork = lwkLiquidNetwork(network);
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

/// The seed every Liquid wallet of [secret] derives from: its BIP39 seed,
/// the words in their own language with its passphrase, as for Bitcoin and
/// the swap key.
///
/// Every existing Liquid wallet is a default wallet, and default wallets
/// have never carried a passphrase, so this is the seed lwk's word-based
/// signer derived for them (`to_seed("")`): the same keys.
///
/// A copy, so the caller can wipe it once lwk has it without touching the
/// secret's own bytes.
@internal
Uint8List liquidSeed(Mnemonic secret) => Uint8List.fromList(secret.seedBytes);

/// lwk's network for [network], one to one. lwk-dart expresses Liquid regtest
/// since SatoshiPortal/lwk-dart#99, so no network is refused or substituted.
@internal
lwk.LiquidNetwork lwkLiquidNetwork(LiquidNetwork network) => switch (network) {
  LiquidNetwork.mainnet => lwk.LiquidNetwork.mainnet,
  LiquidNetwork.testnet => lwk.LiquidNetwork.testnet,
  LiquidNetwork.regtest => lwk.LiquidNetwork.regtest,
};
