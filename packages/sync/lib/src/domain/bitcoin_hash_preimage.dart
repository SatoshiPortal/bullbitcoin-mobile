enum BitcoinPreimageType { sha256, hash256, ripemd160, hash160 }

final class BitcoinHashPreimage {
  final BitcoinPreimageType type;
  final String hash;
  final String preimageHex;

  BitcoinHashPreimage({
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
      other is BitcoinHashPreimage &&
          type == other.type &&
          hash == other.hash &&
          preimageHex == other.preimageHex;

  @override
  int get hashCode => Object.hash(type, hash, preimageHex);

  static bool _isHex(String value) =>
      value.isNotEmpty && RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);
}
