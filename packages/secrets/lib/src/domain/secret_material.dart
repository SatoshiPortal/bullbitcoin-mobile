import 'dart:typed_data';

import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/secret_info.dart';

/// The secret itself: live key material.
///
/// Named for what it is rather than for what holds it. `Secret` is the
/// handle you operate through, `SecretInfo` is what you know about a
/// secret — this is the matter, and the only one of the three that must
/// never cross the package boundary.
///
/// This type is deliberately **not exported** by `secrets.dart` and has
/// **no serialization support**: there is no `toJson`, no mapper, no
/// `dart_mappable` mixin. Encoding a [SecretMaterial] by accident is a
/// compile error rather than a leak. Persistence goes through
/// `SecretModel`, the only type allowed to describe the on-disk shape.
///
/// Callers outside the package never hold one. They hold a [SecretInfo]
/// and ask `Secrets` to perform an operation with it.
///
/// Materialising one costs a PBKDF2 pass, which is why the repository
/// keeps it behind `fetch()` and serves descriptions from `describe()`
/// instead.
sealed class SecretMaterial {
  const SecretMaterial();

  /// Identity of this secret. Taken from the storage key rather than
  /// re-derived — see `SecretRepository`.
  Fingerprint get id;

  /// The 512-bit BIP39 seed, or the raw bytes for a bytes-secret.
  Uint8List get seedBytes;

  /// Non-sensitive projection, safe to hand out.
  SecretInfo get info;

  /// Never widen this. The whole point of the package is that the
  /// default string form of key material is redacted.
  @override
  String toString() => 'SecretMaterial(${info.kind.name}, ${id.hex})';
}

final class MnemonicMaterial extends SecretMaterial {
  @override
  final Fingerprint id;

  /// Identity of the same words with an *empty* passphrase.
  ///
  /// Equal to [id] when there is no passphrase; otherwise a second
  /// PBKDF2 pass, paid only in that case.
  final Fingerprint mnemonicFingerprint;

  final List<String> words;

  /// Empty means "no passphrase". The on-disk model still writes `null`
  /// for absent, see `SecretModel` — the two are equivalent and only the
  /// model may know about the difference.
  final String passphrase;

  @override
  final Uint8List seedBytes;

  const MnemonicMaterial({
    required this.id,
    required this.mnemonicFingerprint,
    required this.words,
    required this.passphrase,
    required this.seedBytes,
  });

  bool get hasPassphrase => passphrase.isNotEmpty;

  @override
  SecretInfo get info => SecretInfo.mnemonic(
    id: id,
    mnemonicFingerprint: mnemonicFingerprint,
    wordCount: words.length,
    hasPassphrase: hasPassphrase,
  );
}

final class SeedMaterial extends SecretMaterial {
  @override
  final Fingerprint id;

  @override
  final Uint8List seedBytes;

  const SeedMaterial({required this.id, required this.seedBytes});

  @override
  SecretInfo get info =>
      SecretInfo.bytes(id: id, lengthInBits: seedBytes.length * 8);
}
