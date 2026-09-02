import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:satoshifier/satoshifier.dart' as satoshifier;
import 'package:satoshifier/utils/descriptor_checksum.dart';

class DescriptorDerivation {
  static ({String external, String internal})
  splitCombinedPublicBitcoinDescriptor(String value, Network network) {
    final canonical = canonicalCombinedPublicBitcoinDescriptor(value, network);
    final parsed = _parseDescriptor(canonical);
    return (
      external: _canonicalPublicBitcoinDescriptor(parsed.external, network),
      internal: _canonicalPublicBitcoinDescriptor(parsed.internal, network),
    );
  }

  static String combinePublicBitcoinDescriptors({
    required String externalDescriptor,
    required String internalDescriptor,
    required Network network,
  }) {
    final parsed = _parseDescriptor(externalDescriptor);
    if (_canonicalPublicBitcoinDescriptor(parsed.external, network) !=
            _canonicalPublicBitcoinDescriptor(externalDescriptor, network) ||
        _canonicalPublicBitcoinDescriptor(parsed.internal, network) !=
            _canonicalPublicBitcoinDescriptor(internalDescriptor, network)) {
      throw const FormatException('Descriptor branches do not match');
    }
    return canonicalCombinedPublicBitcoinDescriptor(parsed.combined, network);
  }

  static String canonicalCombinedPublicBitcoinDescriptor(
    String value,
    Network network,
  ) {
    final parsed = _parseDescriptor(value);
    final combinedBody = parsed.combined;
    if (_canonicalPublicBitcoinDescriptor(value, network) !=
        _canonicalPublicBitcoinDescriptor(combinedBody, network)) {
      throw const FormatException('Combined descriptor required');
    }
    final checksum = DescriptorChecksum.compute(combinedBody);
    if (checksum == null) {
      throw const FormatException('Invalid public wallet descriptor');
    }
    return '$combinedBody#$checksum';
  }

  static Future<String> derivePublicBitcoinDescriptorFromXpriv(
    String xprv, {
    required ScriptType scriptType,
    required bool isTestnet,
    bool isInternalKeychain = false,
  }) async {
    final secretKey = bdk.DescriptorSecretKey.fromString(privateKey: xprv);
    final networkKind = isTestnet ? bdk.NetworkKind.test : bdk.NetworkKind.main;
    final keychain = isInternalKeychain
        ? bdk.KeychainKind.internal
        : bdk.KeychainKind.external_;
    bdk.Descriptor descriptor;

    switch (scriptType) {
      case ScriptType.bip84:
        descriptor = bdk.Descriptor.newBip84(
          secretKey: secretKey,
          keychainKind: keychain,
          networkKind: networkKind,
        );
      case ScriptType.bip49:
        descriptor = bdk.Descriptor.newBip49(
          secretKey: secretKey,
          keychainKind: keychain,
          networkKind: networkKind,
        );
      case ScriptType.bip44:
        descriptor = bdk.Descriptor.newBip44(
          secretKey: secretKey,
          keychainKind: keychain,
          networkKind: networkKind,
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
          network: isTestnet
              ? lwk.LiquidNetwork.testnet
              : lwk.LiquidNetwork.mainnet,
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

satoshifier.Descriptor _parseDescriptor(String value) {
  try {
    return satoshifier.Descriptor.parse(value);
  } on FormatException {
    rethrow;
  } on String {
    throw const FormatException('Invalid public wallet descriptor');
  }
}

String _canonicalPublicBitcoinDescriptor(String value, Network network) {
  if (!network.isBitcoin) {
    throw const FormatException('Only Bitcoin descriptors are supported');
  }
  try {
    final descriptor = bdk.Descriptor(
      descriptor: value,
      networkKind: network.isTestnet
          ? bdk.NetworkKind.test
          : bdk.NetworkKind.main,
    );
    descriptor.sanityCheck();
    final public = descriptor.toString();
    if (descriptor.toStringWithSecret() != public) {
      throw const FormatException('Private wallet descriptor rejected');
    }
    return public;
  } on FormatException {
    rethrow;
  } on Exception {
    throw const FormatException('Invalid public wallet descriptor');
  }
}
