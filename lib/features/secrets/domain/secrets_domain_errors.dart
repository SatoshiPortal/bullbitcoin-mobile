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
