import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;

class DescriptorDerivation {
  static Future<String> derivePublicBitcoinDescriptorFromXpriv(
    String xprv, {
    required ScriptType scriptType,
    required bool isTestnet,
    bool isInternalKeychain = false,
  }) async {
    final secretKey = bdk.DescriptorSecretKey.fromString(privateKey: xprv);
    final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;
    final keychain = isInternalKeychain
        ? bdk.KeychainKind.internal
        : bdk.KeychainKind.external_;
    bdk.Descriptor descriptor;

    switch (scriptType) {
      case ScriptType.bip84:
        descriptor = bdk.Descriptor.newBip84(
          secretKey: secretKey,
          keychainKind: keychain,
          network: network,
        );
      case ScriptType.bip49:
        descriptor = bdk.Descriptor.newBip49(
          secretKey: secretKey,
          keychainKind: keychain,
          network: network,
        );
      case ScriptType.bip44:
        descriptor = bdk.Descriptor.newBip44(
          secretKey: secretKey,
          keychainKind: keychain,
          network: network,
        );
    }

    // `asString` returns the public descriptor.
    return descriptor.toString();
  }

  static Future<String> derivePublicLiquidDescriptorFromMnemonic(
    String mnemonic, {
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    final lwk.Descriptor confidentialDescriptor =
        await lwk.Descriptor.newConfidential(
          network: isTestnet ? lwk.Network.testnet : lwk.Network.mainnet,
          mnemonic: mnemonic,
        );

    return confidentialDescriptor.ctDescriptor;
  }

  static Future<String> deriveBitcoinDescriptorFromXpub(
    String xpub, {
    required String fingerprint,
    required ScriptType scriptType,
    required bool isTestnet,
    bool isInternalKeychain = false,
  }) async {
    final publicKey = bdk.DescriptorPublicKey.fromString(publicKey: xpub);
    final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;
    final keychain = isInternalKeychain
        ? bdk.KeychainKind.internal
        : bdk.KeychainKind.external_;

    bdk.Descriptor.newBip84Public(
      publicKey: publicKey,
      fingerprint: fingerprint,
      keychainKind: keychain,
      network: network,
    );
    bdk.Descriptor descriptor;

    switch (scriptType) {
      case ScriptType.bip84:
        descriptor = bdk.Descriptor.newBip84Public(
          publicKey: publicKey,
          fingerprint: fingerprint,
          keychainKind: keychain,
          network: network,
        );
      case ScriptType.bip49:
        descriptor = bdk.Descriptor.newBip49Public(
          publicKey: publicKey,
          fingerprint: fingerprint,
          keychainKind: keychain,
          network: network,
        );
      case ScriptType.bip44:
        descriptor = bdk.Descriptor.newBip44Public(
          publicKey: publicKey,
          fingerprint: fingerprint,
          keychainKind: keychain,
          network: network,
        );
    }

    return descriptor.toString();
  }
}
