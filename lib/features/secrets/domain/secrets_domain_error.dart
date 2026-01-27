sealed class SecretsDomainError implements Exception {
  final String message;
  final Object? cause;
  const SecretsDomainError(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

// Test-only domain error for unit testing
// TODO: Remove when we have real domain errors to test against
class TestSecretsDomainError extends SecretsDomainError {
  const TestSecretsDomainError(super.message);
}

class InvalidSeedBytesLengthError extends SecretsDomainError {
  final int actualLength;

  const InvalidSeedBytesLengthError(
    super.message, {
    required this.actualLength,
  });
}

class InvalidMnemonicWordCountError extends SecretsDomainError {
  final int actualCount;

  const InvalidMnemonicWordCountError(
    super.message, {
    required this.actualCount,
  });
}

class InvalidPassphraseLengthError extends SecretsDomainError {
  final int actualLength;

  const InvalidPassphraseLengthError(
    super.message, {
    required this.actualLength,
  });
}

class InvalidFingerprintFormatError extends SecretsDomainError {
  final String invalidValue;

  const InvalidFingerprintFormatError(
    super.message, {
    required this.invalidValue,
  });
}
