import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:lwk/lwk.dart' as lwk;

class DescriptorDerivation {
  static Future<String> derivePublicBitcoinDescriptorFromXpriv(
    String xprv, {
    required ScriptType scriptType,
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
      case ScriptType.bip84:
        descriptor = await bdk.Descriptor.newBip84(
          secretKey: secretKey,
          network: network,
          keychain: keychain,
        );
      case ScriptType.bip49:
        descriptor = await bdk.Descriptor.newBip49(
          secretKey: secretKey,
          network: network,
          keychain: keychain,
        );
      case ScriptType.bip44:
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
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    final network = isTestnet ? lwk.Network.testnet : lwk.Network.mainnet;

    // Map ScriptType to lwk.ScriptVariant
    final lwk.ScriptVariant scriptVariant = switch (scriptType) {
      ScriptType.bip84 => lwk.ScriptVariant.wpkh,
      ScriptType.bip49 => lwk.ScriptVariant.shWpkh,
      ScriptType.bip44 => throw UnsupportedError(
          'BIP44 is not supported for Liquid wallets. Use BIP84 or BIP49.',
        ),
    };

    // Use lwk-dart's BIP49 support with proper script variant
    final lwk.Descriptor confidentialDescriptor =
        await lwk.Descriptor.newConfidentialWithScript(
      network: network,
      mnemonic: mnemonic,
      scriptVariant: scriptVariant,
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
      case ScriptType.bip84:
        descriptor = await bdk.Descriptor.newBip84Public(
          publicKey: publicKey,
          fingerPrint: fingerprint,
          network: network,
          keychain: keychain,
        );
      case ScriptType.bip49:
        descriptor = await bdk.Descriptor.newBip49Public(
          publicKey: publicKey,
          fingerPrint: fingerprint,
          network: network,
          keychain: keychain,
        );
      case ScriptType.bip44:
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
