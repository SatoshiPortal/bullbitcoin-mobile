import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/argon2.dart';

abstract final class AccessVerifier {
  static const scheme = 'argon2id-v19';
  // RFC 9106, section 4, second recommended option (64 MiB).
  static const params = 'm=65536,t=3,p=4';
  static const _memory = 65536;
  static const _iterations = 3;
  static const _lanes = 4;
  static const _saltLength = 16;
  static const _verifierLength = 32;

  static Uint8List newSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(_saltLength, (_) => random.nextInt(256)),
    );
  }

  static Future<Uint8List> derive(String candidate, Uint8List salt) =>
      Isolate.run(() => _derive(candidate, salt));

  static bool supports({
    required String storedScheme,
    required String storedParams,
    required Uint8List salt,
    required Uint8List verifier,
  }) =>
      storedScheme == scheme &&
      storedParams == params &&
      salt.length == _saltLength &&
      verifier.length == _verifierLength;

  static bool equals(Uint8List derived, Uint8List expected) {
    var mismatch = 0;
    for (var i = 0; i < _verifierLength; i++) {
      mismatch |= derived[i] ^ expected[i];
    }
    return mismatch == 0;
  }

  static Uint8List _derive(String candidate, Uint8List salt) {
    final input = utf8.encode(candidate);
    try {
      final generator = Argon2BytesGenerator()
        ..init(
          Argon2Parameters(
            Argon2Parameters.ARGON2_id,
            salt,
            desiredKeyLength: _verifierLength,
            memory: _memory,
            iterations: _iterations,
            lanes: _lanes,
          ),
        );
      return generator.process(input);
    } finally {
      input.fillRange(0, input.length, 0);
    }
  }
}
