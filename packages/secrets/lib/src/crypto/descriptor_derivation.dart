import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';

/// Pure descriptor derivation over BDK (Bitcoin) and LWK (Liquid). Ported from
/// the app's `lib/core/utils/descriptor_derivation.dart`. INTERNAL.
class DescriptorDerivation {
  /// Public (watch-only) Bitcoin descriptor for [xprv] at the given keychain.
  static String publicBitcoinDescriptorFromXprv(
    String xprv, {
    required ScriptType scriptType,
    required bool isTestnet,
    required bool internalKeychain,
  }) {
    final secretKey = bdk.DescriptorSecretKey.fromString(privateKey: xprv);
    final networkKind = isTestnet ? bdk.NetworkKind.test : bdk.NetworkKind.main;
    final keychain = internalKeychain
        ? bdk.KeychainKind.internal
        : bdk.KeychainKind.external_;

    final bdk.Descriptor descriptor = switch (scriptType) {
      ScriptType.bip84 => bdk.Descriptor.newBip84(
          secretKey: secretKey, keychainKind: keychain, networkKind: networkKind),
      ScriptType.bip49 => bdk.Descriptor.newBip49(
          secretKey: secretKey, keychainKind: keychain, networkKind: networkKind),
      ScriptType.bip44 => bdk.Descriptor.newBip44(
          secretKey: secretKey, keychainKind: keychain, networkKind: networkKind),
    };
    return descriptor.toString();
  }

  /// Confidential Liquid descriptor from the [mnemonic].
  static Future<String> publicLiquidDescriptorFromMnemonic(
    String mnemonic, {
    required bool isTestnet,
  }) async {
    final descriptor = await lwk.Descriptor.newConfidential(
      network: isTestnet ? lwk.LiquidNetwork.testnet : lwk.LiquidNetwork.mainnet,
      mnemonic: mnemonic,
    );
    return descriptor.ctDescriptor;
  }
}
