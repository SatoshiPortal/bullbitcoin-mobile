import 'dart:math';

import 'package:convert/convert.dart';

class SecretGenerator {
  static List<int> secretBytes(int length) {
    final secureRandomNumberGenerator = Random.secure();
    // A byte is 8 bits, which is 256 possible values to randomnly select
    //  <bytesLength> times from.
    final randomBytes = List<int>.generate(
      length,
      (i) => secureRandomNumberGenerator.nextInt(256),
    );
    return randomBytes;
  }

  static String secretHex(int length) {
    if (length % 2 != 0) throw ArgumentError('Length must be even');

    final randomBytes = secretBytes(length ~/ 2);
    return hex.encode(randomBytes);
  }
}
