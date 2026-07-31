import 'dart:math';
import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/domain/entropy_source.dart';

/// Platform CSPRNG via `Random.secure()` — getrandom(2) on Android,
/// SecRandomCopyBytes on iOS. This is the mandatory floor of the pool: it
/// reaches the kernel RNG through Dart, independently of the Rust binding
/// the bdk draw goes through.
class OsRngSource implements EntropySource {
  const OsRngSource();

  static const _bytes = 64;

  @override
  String get name => EntropySourceName.osRng;

  @override
  bool get mandatory => true;

  @override
  Future<Uint8List> collect() async {
    final random = Random.secure();
    final bytes = Uint8List(_bytes);
    for (var i = 0; i < _bytes; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }
}
