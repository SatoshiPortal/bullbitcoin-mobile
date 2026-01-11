sealed class SeedsDomainError implements Exception {
  final String message;
  final Object? cause;
  const SeedsDomainError(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

// Test-only domain error for unit testing
class TestSeedsDomainError extends SeedsDomainError {
  const TestSeedsDomainError(String message) : super(message);
}
