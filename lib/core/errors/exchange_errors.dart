class ApiKeyException implements Exception {
  final String message;

  ApiKeyException(this.message);

  @override
  String toString() => '[ApiKeyException]: $message';
}
