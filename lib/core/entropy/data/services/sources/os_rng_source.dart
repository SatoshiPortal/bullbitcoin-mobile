import 'dart:math';
import 'dart:typed_data';

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:crypto/crypto.dart';

typedef OsEntropyProvider = Uint8List Function();

/// Produces a fresh draw from Dart's platform CSPRNG binding.
///
/// API failures, malformed draws, an all-identical draw, or an exact repeat
/// within this process abort generation. These checks catch catastrophic
/// failures only; they do not attempt to statistically certify randomness.
class OsRngSource {
  OsRngSource({OsEntropyProvider? provider})
    : _provider = provider ?? _secureBytes;

  static const bytesPerDraw = 64;

  final OsEntropyProvider _provider;
  Uint8List? _lastDigest;

  Future<Uint8List> collect() async {
    final bytes = _provider();
    try {
      if (bytes.length != bytesPerDraw) {
        throw OsEntropyLengthException(bytes.length);
      }
      if (_allBytesEqual(bytes)) {
        throw OsEntropySanityException(
          'Operating-system entropy draw contained one repeated byte value',
        );
      }

      final digest = Uint8List.fromList(sha256.convert(bytes).bytes);
      final previous = _lastDigest;
      if (previous != null && _equal(previous, digest)) {
        _zero(digest);
        throw OsEntropySanityException(
          'Operating-system entropy draw exactly repeated in this process',
        );
      }

      if (previous != null) _zero(previous);
      _lastDigest = digest;
      return bytes;
    } catch (_) {
      _zero(bytes);
      rethrow;
    }
  }

  static Uint8List _secureBytes() {
    final random = Random.secure();
    final bytes = Uint8List(bytesPerDraw);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  static bool _allBytesEqual(Uint8List bytes) {
    final first = bytes.first;
    for (var i = 1; i < bytes.length; i++) {
      if (bytes[i] != first) return false;
    }
    return true;
  }

  static bool _equal(Uint8List left, Uint8List right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left[i] ^ right[i];
    }
    return difference == 0;
  }

  static void _zero(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }
}

class OsEntropyLengthException extends BullException {
  OsEntropyLengthException(int length)
    : super(
        'Operating-system entropy source delivered $length bytes; '
        'expected ${OsRngSource.bytesPerDraw}',
      );
}

class OsEntropySanityException extends BullException {
  OsEntropySanityException(super.message);
}
