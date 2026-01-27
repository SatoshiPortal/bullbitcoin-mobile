import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:meta/meta.dart';

/// BIP32 fingerprint - 4 bytes represented as 8 hex characters
@immutable
class Fingerprint {
  final String value;

  const Fingerprint._(this.value);

  /// Creates a Fingerprint instance with validation.
  ///
  /// Throws [InvalidFingerprintFormatError] if the hex string is not exactly 8 hex characters.
  factory Fingerprint.fromHex(String hex) {
    if (hex.length != 8) {
      throw InvalidFingerprintFormatError(
        'BIP32 fingerprint must be 8 hex characters, got: ${hex.length}',
        invalidValue: hex,
      );
    }
    // Validate hex format
    if (!RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(hex)) {
      throw InvalidFingerprintFormatError(
        'Fingerprint must be valid hex string',
        invalidValue: hex,
      );
    }
    return Fingerprint._(hex.toLowerCase());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Fingerprint &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Fingerprint($value)';
}
