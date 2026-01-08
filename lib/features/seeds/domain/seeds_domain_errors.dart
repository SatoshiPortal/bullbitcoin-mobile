sealed class SeedsDomainError implements Exception {
  final String message;
  final Object? cause;
  const SeedsDomainError(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}
