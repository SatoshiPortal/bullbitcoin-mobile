class InvalidMempoolUrlException implements Exception {
  final String message;

  InvalidMempoolUrlException(this.message);

  @override
  String toString() => 'InvalidMempoolUrlException: $message';
}

enum MempoolValidationErrorType {
  connectionTimeout,
  hostNotFound,
  torNotRunning,
  connectionError,
  notMempoolServer,
  serverUnavailable,
  serverError,
  invalidResponse,
  unexpected,
}

class MempoolServerValidationException implements Exception {
  final MempoolValidationErrorType errorType;
  final Object? cause;

  MempoolServerValidationException(this.errorType, [this.cause]);

  @override
  String toString() =>
      'MempoolServerValidationException: $errorType${cause != null ? ' (cause: $cause)' : ''}';
}
