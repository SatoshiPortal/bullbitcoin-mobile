import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/exceptions.dart';
import 'package:secrets/src/domain/domain.dart';

/// Liquid derivations through lwk. Reached as `Deriver.liquid`.
///
/// Takes [MnemonicMaterial], never a bare `SecretMaterial`: lwk derives
/// from the BIP39 words, so a seed-only secret is refused by the type
/// before anything is computed.
final class LiquidDeriver {
  const LiquidDeriver();

  /// The confidential descriptor, which covers both keychains.
  ///
  /// ⚠️ **A passphrase takes no part.** lwk has no passphrase parameter at
  /// any layer and its signer hard-codes `to_seed("")`, so a passphrase
  /// secret gets its passphrase-less sibling's descriptor — same
  /// addresses, same funds. `Secret.liquidDescriptor` marks the result
  /// `WordsOnly` for exactly that reason. See doc/design.md, § Passphrase.
  ///
  /// Regtest is refused rather than folded into testnet: Elements
  /// regtest is a different chain, and a confidential descriptor built
  /// for testnet would hand back addresses that do not belong to it.
  Future<String> descriptor(
    MnemonicMaterial secret, {
    required LiquidNetwork network,
  }) async {
    final descriptor = await lwk.Descriptor.newConfidential(
      network: switch (network) {
        LiquidNetwork.mainnet => lwk.LiquidNetwork.mainnet,
        LiquidNetwork.testnet => lwk.LiquidNetwork.testnet,
        LiquidNetwork.regtest => throw const UnsupportedLiquidNetwork(
          'lwk cannot express Liquid regtest',
        ),
      },
      mnemonic: secret.words.join(' '),
    );
    // A plain value, not an FRB opaque: `Descriptor` is one `String` field,
    // so there is no native handle to release here.
    return descriptor.ctDescriptor;
  }
}
