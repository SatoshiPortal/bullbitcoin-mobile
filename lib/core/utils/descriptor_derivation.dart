import 'package:bb_mobile/core/utils/bip32_derivation.dart';
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

  static String derivePublicBitcoinMultipathDescriptorFromXpub(
    String xpub, {
    required ScriptType scriptType,
    required bool isTestnet,
    String? masterFingerprint,
    String? derivationPath,
  }) {
    if (masterFingerprint == null && derivationPath != null) {
      throw ArgumentError('derivationPath requires a masterFingerprint');
    }

    final accountKey = Bip32Derivation.getBip32Xpub(xpub);
    final canonicalXpub = accountKey.convert(
      isTestnet ? XpubType.tpub : XpubType.xpub,
    );
    final origin = switch ((masterFingerprint, derivationPath)) {
      (null, null) => '',
      (final fingerprint?, null) => '[${fingerprint.toLowerCase()}]',
      (final fingerprint?, final path?) =>
        '[${fingerprint.toLowerCase()}/${_withoutMasterPrefix(path)}]',
      _ => throw StateError('Invalid descriptor origin'),
    };
    final descriptorKey = '$origin$canonicalXpub/<0;1>/*';
    final descriptorString = switch (scriptType) {
      ScriptType.bip84 => 'wpkh($descriptorKey)',
      ScriptType.bip49 => 'sh(wpkh($descriptorKey))',
      ScriptType.bip44 => 'pkh($descriptorKey)',
    };
    final descriptor = bdk.Descriptor(
      descriptor: descriptorString,
      networkKind: isTestnet ? bdk.NetworkKind.test : bdk.NetworkKind.main,
    );
    descriptor.sanityCheck();
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

  static String _withoutMasterPrefix(String derivationPath) =>
      derivationPath.startsWith('m/')
      ? derivationPath.substring(2)
      : derivationPath;
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
