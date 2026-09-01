import 'package:bb_mobile/core/utils/uint_8_list_x.dart';
import 'package:flutter/foundation.dart' show Uint8List;

/// Hand-written instead of Freezed-generated: every variant of [Seed] carries
/// key material, and the generated members handed it out three ways —
/// `toString` printed the mnemonic words, the passphrase and the raw seed
/// bytes; `==`/`hashCode` ran a [DeepCollectionEquality] over the words, which
/// turns comparison into an oracle for guessing them; and the
/// `DiagnosticableTreeMixin`/`debugFillProperties` pair published all of it to
/// the widget inspector and to every framework error dump that walks the tree.
///
/// So the variants below redact their secrets in `toString`, mix in no
/// diagnostics, and keep identity equality. Nothing in the codebase compares
/// seeds by value, copies them with `copyWith`, or uses one as a `Map`/`Set`
/// key — [masterFingerprint] is the identifier seeds are matched on.
sealed class Seed {
  final Uint8List bytes;
  final String masterFingerprint;

  const Seed._({required this.bytes, required this.masterFingerprint});

  /// Bytes-based seed
  const factory Seed.bytes({
    required Uint8List bytes,
    required String masterFingerprint,
  }) = BytesSeed;

  /// Mnemonic-based seed
  const factory Seed.mnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
    required Uint8List bytes,
    required String masterFingerprint,
  }) = MnemonicSeed;

  String get hex => bytes.toHexString();
}

/// Carries raw seed bytes. See [Seed] for why `toString` is redacted and
/// equality is identity-based.
final class BytesSeed extends Seed {
  const BytesSeed({required super.bytes, required super.masterFingerprint})
    : super._();

  @override
  String toString() =>
      'BytesSeed(bytes: <redacted>, '
      'masterFingerprint: $masterFingerprint)';
}

/// Carries the mnemonic words, an optional passphrase and the derived seed
/// bytes. See [Seed] for why `toString` is redacted and equality is
/// identity-based.
///
/// `passphrase` is redacted unconditionally, including when it is null: a
/// `passphrase: null` in a log line tells an attacker which seeds are worth
/// attacking without one.
final class MnemonicSeed extends Seed {
  final List<String> mnemonicWords;
  final String? passphrase;

  const MnemonicSeed({
    required this.mnemonicWords,
    this.passphrase,
    required super.bytes,
    required super.masterFingerprint,
  }) : super._();

  @override
  String toString() =>
      'MnemonicSeed(mnemonicWords: <redacted>, passphrase: <redacted>, '
      'bytes: <redacted>, masterFingerprint: $masterFingerprint)';
}
