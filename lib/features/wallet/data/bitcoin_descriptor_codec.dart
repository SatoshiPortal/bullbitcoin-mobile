import 'package:primitives/primitives.dart' as primitives;
import 'package:sync/sync.dart' as sync;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';

import 'bitcoin_policy_codec.dart';

typedef BdkDescriptorKey = sync.BitcoinDescriptorKey;

final class BdkTwoPathDescriptor {
  final String descriptor;
  final String externalDescriptor;
  final String internalDescriptor;
  final String scriptIdentity;
  final ScriptType? scriptType;
  final List<BdkDescriptorKey> keys;
  final List<BdkDescriptorKey> policyKeys;
  final Set<String> unspendablePolicyKeyIdentifiers;
  final bool inferredChangePath;

  const BdkTwoPathDescriptor({
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

class BdkFacade {
  static BdkTwoPathDescriptor parsePublicTwoPathDescriptor({
    required String descriptor,
    required Network network,
  }) {
    final parsed = policyValue(
      const sync.BitcoinPolicyCodec().parseDescriptor(
        descriptor: descriptor,
        network: network.bitcoin,
      ),
    );
    return BdkTwoPathDescriptor(
      descriptor: parsed.descriptor,
      externalDescriptor: parsed.externalDescriptor,
      internalDescriptor: parsed.internalDescriptor,
      scriptIdentity: parsed.scriptIdentity,
      scriptType: switch (parsed.scriptType) {
        primitives.ScriptType.bip84 => ScriptType.bip84,
        primitives.ScriptType.bip49 => ScriptType.bip49,
        primitives.ScriptType.bip44 => ScriptType.bip44,
        null => null,
      },
      keys: parsed.keys,
      policyKeys: parsed.policyKeys,
      unspendablePolicyKeyIdentifiers: parsed.unspendablePolicyKeyIdentifiers,
      inferredChangePath: parsed.inferredChangePath,
    );
  }

  static String combinePublicDescriptorPair({
    required String externalDescriptor,
    required String internalDescriptor,
    required Network network,
  }) => policyValue(
    const sync.BitcoinPolicyCodec().combineDescriptorPair(
      externalDescriptor: externalDescriptor,
      internalDescriptor: internalDescriptor,
      network: network.bitcoin,
    ),
  );
}
