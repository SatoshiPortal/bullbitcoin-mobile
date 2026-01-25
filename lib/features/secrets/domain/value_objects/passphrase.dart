import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';
import 'package:meta/meta.dart';

@immutable
class Passphrase {
  final String value;

  const Passphrase._(this.value);

  /// Creates a Passphrase instance with validation.
  ///
  /// Throws [InvalidPassphraseLengthError] if the passphrase exceeds 256 characters.
  factory Passphrase(String passphrase) {
    const maxLength = 256;
    if (passphrase.length > maxLength) {
      throw InvalidPassphraseLengthError(
        'Passphrase cannot exceed $maxLength characters. Got ${passphrase.length} characters.',
        actualLength: passphrase.length,
      );
    }

    return Passphrase._(passphrase);
  }

  /// Creates an empty passphrase.
  factory Passphrase.empty() => const Passphrase._('');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Passphrase &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}
