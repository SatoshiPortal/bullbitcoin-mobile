/// BIP-380 output descriptor checksum.
///
/// The checksum is a BCH code over a 40-bit field, chosen so that any error
/// affecting up to 4 characters is always detected. It is the only integrity
/// signal a descriptor carries: without verifying it, a descriptor mistyped
/// or mangled in transit builds a watch-only wallet on the wrong key, and the
/// user only finds out when funds do not appear.
///
/// Reference: BIP-380, "Checksum".
class DescriptorChecksum {
  DescriptorChecksum._();

  /// Characters allowed in a descriptor body, in the order that defines each
  /// character's value. The split is cosmetic; the concatenation is the
  /// 96-character INPUT_CHARSET of the spec.
  static const String _inputCharset =
      r"0123456789()[],'/*abcdefgh@:$%{}"
      r'IJKLMNOPQRSTUVWXYZ&+-.;<=>?!^_|~'
      r'ijklmnopqrstuvwxyzABCDEFGH`#"\ ';

  /// Bech32 charset, used for the 8 checksum characters themselves.
  static const String _checksumCharset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

  static const List<int> _generator = [
    0xf5dee51989,
    0xa9fdca3312,
    0x1bab10e32d,
    0x3706b1677a,
    0x644d626ffd,
  ];

  static int _polymod(List<int> symbols) {
    var chk = 1;
    for (final value in symbols) {
      final top = chk >> 35;
      chk = ((chk & 0x7ffffffff) << 5) ^ value;
      for (var i = 0; i < 5; i++) {
        if ((top >> i) & 1 == 1) chk ^= _generator[i];
      }
    }
    return chk;
  }

  /// Maps the descriptor body to checksum symbols, or null if it contains a
  /// character the spec does not allow.
  static List<int>? _expand(String body) {
    final symbols = <int>[];
    final groups = <int>[];
    for (final char in body.split('')) {
      final index = _inputCharset.indexOf(char);
      if (index < 0) return null;
      symbols.add(index & 31);
      groups.add(index >> 5);
      if (groups.length == 3) {
        symbols.add(groups[0] * 9 + groups[1] * 3 + groups[2]);
        groups.clear();
      }
    }
    if (groups.length == 1) {
      symbols.add(groups[0]);
    } else if (groups.length == 2) {
      symbols.add(groups[0] * 3 + groups[1]);
    }
    return symbols;
  }

  /// Computes the 8-character checksum for a descriptor [body], which must be
  /// given without its `#checksum` suffix. Returns null if the body contains
  /// a character outside the descriptor charset.
  static String? compute(String body) {
    final symbols = _expand(body);
    if (symbols == null) return null;
    final checksum = _polymod([...symbols, 0, 0, 0, 0, 0, 0, 0, 0]) ^ 1;
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buffer.write(_checksumCharset[(checksum >> (5 * (7 - i))) & 31]);
    }
    return buffer.toString();
  }

  /// Verifies the `#checksum` suffix of [descriptor] if one is present.
  ///
  /// A descriptor without a suffix is accepted: the suffix is optional in
  /// BIP-380 and several wallets still export descriptors without it, so
  /// rejecting them would break importing an otherwise valid backup. When a
  /// suffix is present it must be correct — a wrong one means the string was
  /// damaged, which is exactly what it is there to detect.
  static bool isValid(String descriptor) {
    final hashIndex = descriptor.indexOf('#');
    if (hashIndex < 0) return true;
    final body = descriptor.substring(0, hashIndex);
    final suffix = descriptor.substring(hashIndex + 1);
    if (suffix.length != 8) return false;
    if (body.contains('#')) return false;
    return compute(body) == suffix;
  }
}
