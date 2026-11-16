import 'package:primitives/primitives.dart';

final class BitcoinDescriptorKey {
  final String id;
  final String masterFingerprint;
  final String xpubFingerprint;
  final String xpub;
  final String? derivationPath;
  final String descriptorPath;

  const BitcoinDescriptorKey({
    this.id = '',
    required this.masterFingerprint,
    required this.xpubFingerprint,
    required this.xpub,
    required this.derivationPath,
    this.descriptorPath = '',
  });
}

final class ParsedBitcoinDescriptor {
  final String descriptor;
  final String externalDescriptor;
  final String internalDescriptor;
  final String scriptIdentity;
  final ScriptType? scriptType;
  final List<BitcoinDescriptorKey> keys;
  final List<BitcoinDescriptorKey> policyKeys;
  final Set<String> unspendablePolicyKeyIdentifiers;
  final bool inferredChangePath;

  const ParsedBitcoinDescriptor({
    required this.descriptor,
    required this.externalDescriptor,
    required this.internalDescriptor,
    required this.scriptIdentity,
    required this.scriptType,
    this.keys = const [],
    this.policyKeys = const [],
    this.unspendablePolicyKeyIdentifiers = const {},
    this.inferredChangePath = false,
  });
}

/// Public descriptor and concrete network for wallet-free policy analysis.
final class BitcoinPolicyDescriptor {
  final String descriptor;
  final BitcoinNetwork network;

  const BitcoinPolicyDescriptor({
    required this.descriptor,
    required this.network,
  });
}
