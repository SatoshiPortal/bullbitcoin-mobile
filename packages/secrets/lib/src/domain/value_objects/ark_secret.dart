import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:secrets/src/domain/secrets_error.dart';

/// The ARK secret derived from BIP85 hex (index 11811, len 32). SECRET — the
/// raw [bytes] are marked `@internal` so only the in-package consumer that
/// builds the ARK node can read them; external reads trip the seal lint.
@immutable
class ArkSecret {
  ArkSecret(Uint8List bytes) : _bytes = Uint8List.fromList(bytes) {
    if (_bytes.length != 32) {
      throw InvalidArkSecretError('ArkSecret must be 32 bytes', 'bytes.length');
    }
  }

  final Uint8List _bytes;

  /// SECRET — internal consumers only.
  @internal
  Uint8List get bytes => Uint8List.fromList(_bytes);

  @override
  String toString() => 'ArkSecret(32 bytes)';
}
