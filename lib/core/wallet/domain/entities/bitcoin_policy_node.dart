import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';

enum BitcoinPolicyKeyKind {
  descriptorKey,
  publicKey,
  xOnlyPublicKey,
  fingerprint,
}

enum BitcoinPolicyKeychain { external, internal }

final class BitcoinPolicyKey {
  final BitcoinPolicyKeyKind kind;
  final String value;

  BitcoinPolicyKey({required this.kind, required String value})
    : value = value.toLowerCase() {
    if (value.isEmpty) throw ArgumentError.value(value, 'value');
  }

  bool matches(WalletDescriptorKey descriptorKey) {
    final identifiers = switch (kind) {
      BitcoinPolicyKeyKind.descriptorKey => {descriptorKey.id.toLowerCase()},
      BitcoinPolicyKeyKind.fingerprint => {
        descriptorKey.masterFingerprint.toLowerCase(),
        descriptorKey.xpubFingerprint.toLowerCase(),
      },
      BitcoinPolicyKeyKind.publicKey ||
      BitcoinPolicyKeyKind.xOnlyPublicKey => {descriptorKey.xpub.toLowerCase()},
    };
    return identifiers.contains(value);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BitcoinPolicyKey && kind == other.kind && value == other.value;

  @override
  int get hashCode => Object.hash(kind, value);
}

sealed class BitcoinPolicyNode {
  final String id;

  const BitcoinPolicyNode({required this.id});
}

final class BitcoinSignaturePolicyNode extends BitcoinPolicyNode {
  final BitcoinPolicyKey key;

  const BitcoinSignaturePolicyNode({required super.id, required this.key});
}

enum BitcoinHashlockType { sha256, hash256, ripemd160, hash160 }

final class BitcoinPolicyPreimage {
  final BitcoinHashlockType type;
  final String hash;
  final String preimageHex;

  BitcoinPolicyPreimage({
    required this.type,
    required String hash,
    required String preimageHex,
  }) : hash = hash.toLowerCase(),
       preimageHex = preimageHex.toLowerCase() {
    if (!_isHex(this.hash)) throw ArgumentError.value(hash, 'hash');
    if (this.preimageHex.length != 64 || !_isHex(this.preimageHex)) {
      throw ArgumentError.value(preimageHex, 'preimageHex');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BitcoinPolicyPreimage &&
          type == other.type &&
          hash == other.hash &&
          preimageHex == other.preimageHex;

  @override
  int get hashCode => Object.hash(type, hash, preimageHex);

  static bool _isHex(String value) =>
      value.isNotEmpty && RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);
}

final class BitcoinHashlockPolicyNode extends BitcoinPolicyNode {
  final BitcoinHashlockType type;
  final String hash;

  BitcoinHashlockPolicyNode({
    required super.id,
    required this.type,
    required this.hash,
  }) {
    if (hash.isEmpty) throw ArgumentError.value(hash, 'hash');
  }
}

enum BitcoinAbsoluteTimelockType { blockHeight, timestamp }

final class BitcoinAbsoluteTimelockPolicyNode extends BitcoinPolicyNode {
  final BitcoinAbsoluteTimelockType type;
  final int value;

  BitcoinAbsoluteTimelockPolicyNode({
    required super.id,
    required this.type,
    required this.value,
  }) {
    if (value < 0) throw ArgumentError.value(value, 'value');
  }
}

enum BitcoinRelativeTimelockType { blocks, seconds }

final class BitcoinRelativeTimelockPolicyNode extends BitcoinPolicyNode {
  final BitcoinRelativeTimelockType type;
  final int value;

  BitcoinRelativeTimelockPolicyNode({
    required super.id,
    this.type = BitcoinRelativeTimelockType.blocks,
    required this.value,
  }) {
    if (value < 0) throw ArgumentError.value(value, 'value');
  }
}

final class BitcoinThresholdPolicyNode extends BitcoinPolicyNode {
  final int threshold;
  final List<BitcoinPolicyNode> children;
  final bool requiresPath;

  BitcoinThresholdPolicyNode({
    required super.id,
    required this.threshold,
    required List<BitcoinPolicyNode> children,
    this.requiresPath = false,
  }) : children = List.unmodifiable(children) {
    if (children.isEmpty) throw ArgumentError.value(children, 'children');
    if (threshold < 1 || threshold > children.length) {
      throw ArgumentError.value(threshold, 'threshold');
    }
  }

  bool get requiresSelection => requiresPath && threshold < children.length;
}
