import 'dart:math';
import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/domain/entropy_source.dart';

/// Platform CSPRNG via `Random.secure()`.
///
/// Source-verified chain (Dart 3.10.4 / Flutter engine): the engine
/// registers `dart::bin::GetEntropy`, which is a plain
/// `open("/dev/urandom") + read()` on BOTH Android and iOS — not
/// getrandom(2)/getentropy/SecRandomCopyBytes. The device is backed by the
/// kernel CSPRNG on both platforms. If the open or read fails (sandbox,
/// fd exhaustion), the VM throws and wallet creation aborts — no fallback.
///
/// This is the mandatory floor of the pool: it reaches the kernel RNG
/// through a file-descriptor read in the Dart VM's C++, a code path
/// disjoint from the raw getrandom(2) syscall / CCRandomGenerateBytes
/// path the bdk draw takes through Rust — binding diversity over the same
/// OS entropy root.
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
