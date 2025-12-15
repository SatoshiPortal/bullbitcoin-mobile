sealed class ElectrumServerException implements Exception {
  final String message;

  ElectrumServerException(this.message);

  @override
  String toString() => message;
}

class InvalidPriorityException extends ElectrumServerException {
  final int value;

  InvalidPriorityException(this.value)
    : super('priority must be non-negative, got: $value');
}

class InvalidPortException extends ElectrumServerException {
  final int port;

  InvalidPortException(this.port)
    : super('Invalid port: $port. Port must be between 1 and 65535.');
}
