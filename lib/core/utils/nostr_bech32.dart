import 'package:bech32/bech32.dart';

abstract final class NostrBech32 {
  static String npub(List<int> publicKeyBytes) =>
      _encode('npub', publicKeyBytes);

  static String nsec(List<int> privateKeyBytes) =>
      _encode('nsec', privateKeyBytes);

  static String _encode(String prefix, List<int> bytes) {
    if (bytes.length != 32) {
      throw ArgumentError.value(bytes.length, 'bytes.length', 'Must be 32');
    }
    return bech32.encode(Bech32(prefix, _convertBits(bytes)));
  }

  static List<int> _convertBits(List<int> bytes) {
    var accumulator = 0;
    var bitCount = 0;
    final output = <int>[];
    const outputBits = 5;
    const mask = (1 << outputBits) - 1;
    const maxAccumulator = (1 << (8 + outputBits - 1)) - 1;
    for (final byte in bytes) {
      accumulator = ((accumulator << 8) | byte) & maxAccumulator;
      bitCount += 8;
      while (bitCount >= outputBits) {
        bitCount -= outputBits;
        output.add((accumulator >> bitCount) & mask);
      }
    }
    if (bitCount > 0) {
      output.add((accumulator << (outputBits - bitCount)) & mask);
    }
    return output;
  }
}
