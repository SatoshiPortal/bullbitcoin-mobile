import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_wallet_metadata_entity.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:lwk/lwk.dart' as lwk;

class NewDescriptorDerivation {
  static Future<String> derivePublicBitcoinDescriptorFromXpriv(
    String xprv, {
    required NewScriptType scriptType,
    required bool isTestnet,
    bool isInternalKeychain = false,
  }) async {
    final secretKey = await bdk.DescriptorSecretKey.fromString(xprv);
    final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;
    final keychain =
        isInternalKeychain
            ? bdk.KeychainKind.internalChain
            : bdk.KeychainKind.externalChain;
    bdk.Descriptor descriptor;

    switch (scriptType) {
      case NewScriptType.bip84:
        descriptor = await bdk.Descriptor.newBip84(
          secretKey: secretKey,
          network: network,
          keychain: keychain,
        );
      case NewScriptType.bip49:
        descriptor = await bdk.Descriptor.newBip49(
          secretKey: secretKey,
          network: network,
          keychain: keychain,
        );
      case NewScriptType.bip44:
        descriptor = await bdk.Descriptor.newBip44(
          secretKey: secretKey,
          network: network,
          keychain: keychain,
        );
    }

    // `asString` returns the public descriptor.
    return descriptor.asString();
  }

  static Future<String> derivePublicLiquidDescriptorFromMnemonic(
    String mnemonic, {
    required NewScriptType scriptType,
    required bool isTestnet,
  }) async {
    final lwk.Descriptor confidentialDescriptor = await lwk
        .Descriptor.newConfidential(
      network: isTestnet ? lwk.Network.testnet : lwk.Network.mainnet,
      mnemonic: mnemonic,
    );

    return confidentialDescriptor.ctDescriptor;
  }

  static Future<String> deriveBitcoinDescriptorFromXpub(
    String xpub, {
    required String fingerprint,
    required NewScriptType scriptType,
    required bool isTestnet,
    bool isInternalKeychain = false,
  }) async {
    final publicKey = await bdk.DescriptorPublicKey.fromString(xpub);
    final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;
    final keychain =
        isInternalKeychain
            ? bdk.KeychainKind.internalChain
            : bdk.KeychainKind.externalChain;

    await bdk.Descriptor.newBip84Public(
      publicKey: publicKey,
      fingerPrint: fingerprint,
      network: network,
      keychain: keychain,
    );
    bdk.Descriptor descriptor;

    switch (scriptType) {
      case NewScriptType.bip84:
        descriptor = await bdk.Descriptor.newBip84Public(
          publicKey: publicKey,
          fingerPrint: fingerprint,
          network: network,
          keychain: keychain,
        );
      case NewScriptType.bip49:
        descriptor = await bdk.Descriptor.newBip49Public(
          publicKey: publicKey,
          fingerPrint: fingerprint,
          network: network,
          keychain: keychain,
        );
      case NewScriptType.bip44:
        descriptor = await bdk.Descriptor.newBip44Public(
          publicKey: publicKey,
          fingerPrint: fingerprint,
          network: network,
          keychain: keychain,
        );
    }

    return descriptor.asString();
  }
}
