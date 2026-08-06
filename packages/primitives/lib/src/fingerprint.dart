import 'package:meta/meta.dart';

/// A BIP32 master-key fingerprint: 8 lowercase hex chars (4 bytes).
///
/// This is a display-only, public identity. It conveys which seed, never
/// authority over it: a 4-byte fingerprint is public and only 2^32 wide.
@immutable
class Fingerprint {
  final String hex;

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

  static final RegExp _pattern = RegExp(r'^[0-9a-f]{8}$');

  /// Non-throwing parse for untrusted input.
  static Fingerprint? tryParse(String hex) {
    final lower = hex.toLowerCase();
    return _pattern.hasMatch(lower) ? Fingerprint._(lower) : null;
  }

  @override
  bool operator ==(Object other) => other is Fingerprint && other.hex == hex;

  @override
  int get hashCode => hex.hashCode;

  @override
  String toString() => 'Fingerprint($hex)';
}
