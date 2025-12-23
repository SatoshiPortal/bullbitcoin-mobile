class InvalidMempoolUrlException implements Exception {
  final String message;

  InvalidMempoolUrlException(this.message);

  @override
  String toString() => 'InvalidMempoolUrlException: $message';
}

class MempoolServerValidationException implements Exception {
  final String message;
  final Object? cause;

  MempoolServerValidationException(this.message, [this.cause]);

  @override
  String toString() =>
      'MempoolServerValidationException: $message${cause != null ? ' (cause: $cause)' : ''}';
}
