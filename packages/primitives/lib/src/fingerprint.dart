import 'package:meta/meta.dart';

/// A BIP32 master-key fingerprint — 8 lowercase hex chars (4 bytes).
///
/// This is a **display-only, public identity**. It conveys *which* seed, never
/// *authority* over it: a 4-byte fingerprint is public and only 2³² wide, so a
/// destructive action keyed on it (delete/purge) must sit behind a confirmed
/// use-case, and the seed store rejects importing a second seed with an
/// already-present fingerprint (collision-safe handle).
///
/// The unnamed constructor is for literals / known-good values and **throws**
/// `ArgumentError` (programmer-bug bucket) on a malformed value. For untrusted
/// input (restore data, off-the-wire) use [Fingerprint.tryParse], which yields
/// `null` instead of throwing so the caller can model it as a failure.
@immutable
class Fingerprint {
  factory Fingerprint(String hex) {
    if (!_pattern.hasMatch(hex)) {
      throw ArgumentError.value(
        hex,
        'hex',
        'Fingerprint must be 8 lowercase hex characters',
      );
    }
    return Fingerprint._(hex);
  }

  const Fingerprint._(this.hex);

  /// Non-throwing parse for untrusted input. Returns `null` if [hex] is not
  /// exactly 8 lowercase hex characters.
  static Fingerprint? tryParse(String hex) =>
      _pattern.hasMatch(hex) ? Fingerprint._(hex) : null;

  static final RegExp _pattern = RegExp(r'^[0-9a-f]{8}$');

  final String hex;

  @override
  bool operator ==(Object other) =>
      other is Fingerprint && other.hex == hex;

  @override
  int get hashCode => hex.hashCode;

  @override
  String toString() => 'Fingerprint($hex)';
}
