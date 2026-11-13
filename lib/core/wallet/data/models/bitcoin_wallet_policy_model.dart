enum BitcoinPolicyNodeModelType {
  signature,
  sha256,
  hash256,
  ripemd160,
  hash160,
  absoluteBlockHeight,
  absoluteTimestamp,
  relativeBlocks,
  relativeSeconds,
  threshold,
}

enum BitcoinPolicyKeyModelType {
  descriptorKey,
  publicKey,
  xOnlyPublicKey,
  fingerprint,
}

final class BitcoinPolicyKeyModel {
  final BitcoinPolicyKeyModelType type;
  final String value;

  const BitcoinPolicyKeyModel({required this.type, required this.value});
}

final class BitcoinPolicyNodeModel {
  final String id;
  final BitcoinPolicyNodeModelType type;
  final BitcoinPolicyKeyModel? key;
  final String? hash;
  final int? value;
  final int? threshold;
  final bool requiresPath;
  final List<BitcoinPolicyNodeModel> children;
  final List<int> pathChildIndices;

  BitcoinPolicyNodeModel({
    required this.id,
    required this.type,
    this.key,
    this.hash,
    this.value,
    this.threshold,
    this.requiresPath = false,
    List<BitcoinPolicyNodeModel> children = const [],
    List<int>? pathChildIndices,
  }) : children = List.unmodifiable(children),
       pathChildIndices = List.unmodifiable(
         pathChildIndices ?? List.generate(children.length, (index) => index),
       ) {
    if (this.pathChildIndices.length != children.length) {
      throw ArgumentError.value(pathChildIndices, 'pathChildIndices');
    }
  }
}

final class BitcoinSpendingPolicyModel {
  final BitcoinPolicyNodeModel root;
  final bool requiresPath;

  const BitcoinSpendingPolicyModel({
    required this.root,
    required this.requiresPath,
  });
}

final class BitcoinWalletPolicyModel {
  final BitcoinSpendingPolicyModel external;
  final BitcoinSpendingPolicyModel internal;

  const BitcoinWalletPolicyModel({
    required this.external,
    required this.internal,
  });
}
