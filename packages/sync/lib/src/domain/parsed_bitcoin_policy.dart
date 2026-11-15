enum ParsedPolicyNodeType {
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

enum ParsedPolicyKeyType {
  descriptorKey,
  publicKey,
  xOnlyPublicKey,
  fingerprint,
}

final class ParsedPolicyKey {
  final ParsedPolicyKeyType type;
  final String value;

  const ParsedPolicyKey({required this.type, required this.value});
}

final class ParsedPolicyNode {
  final String id;
  final ParsedPolicyNodeType type;
  final ParsedPolicyKey? key;
  final String? hash;
  final int? value;
  final int? threshold;
  final bool requiresPath;
  final List<ParsedPolicyNode> children;
  final List<int> pathChildIndices;

  ParsedPolicyNode({
    required this.id,
    required this.type,
    this.key,
    this.hash,
    this.value,
    this.threshold,
    this.requiresPath = false,
    List<ParsedPolicyNode> children = const [],
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

final class ParsedKeychainPolicy {
  final ParsedPolicyNode root;
  final bool requiresPath;

  const ParsedKeychainPolicy({required this.root, required this.requiresPath});
}

final class ParsedBitcoinPolicy {
  final ParsedKeychainPolicy external;
  final ParsedKeychainPolicy internal;

  const ParsedBitcoinPolicy({required this.external, required this.internal});
}
