sealed class SettingsDomainError implements Exception {
  final String message;
  final Object? cause;
  const SettingsDomainError(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

// Add specific domain errors here as needed. Since the current domain is mainly
// constructed of primitives, there are no specific errors defined yet.
