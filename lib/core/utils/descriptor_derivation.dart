import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

class DescriptorDerivation {
  static Future<String> deriveBitcoinDescriptorFromXpub(
    String xpub, {
    required String fingerprint,
    required ScriptType scriptType,
    required bool isTestnet,
    bool isInternalKeychain = false,
  }) async {
    final publicKey = bdk.DescriptorPublicKey.fromString(publicKey: xpub);
    final networkKind = isTestnet ? bdk.NetworkKind.test : bdk.NetworkKind.main;
    final keychain = isInternalKeychain
        ? bdk.KeychainKind.internal
        : bdk.KeychainKind.external_;

    bdk.Descriptor descriptor;

    switch (scriptType) {
      case ScriptType.bip84:
        descriptor = bdk.Descriptor.newBip84Public(
          publicKey: publicKey,
          fingerprint: fingerprint,
          keychainKind: keychain,
          networkKind: networkKind,
        );
      case ScriptType.bip49:
        descriptor = bdk.Descriptor.newBip49Public(
          publicKey: publicKey,
          fingerprint: fingerprint,
          keychainKind: keychain,
          networkKind: networkKind,
        );
      case ScriptType.bip44:
        descriptor = bdk.Descriptor.newBip44Public(
          publicKey: publicKey,
          fingerprint: fingerprint,
          keychainKind: keychain,
          networkKind: networkKind,
        );
    }

    return descriptor.toString();
  }
}
