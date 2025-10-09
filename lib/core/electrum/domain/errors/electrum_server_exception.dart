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

class InvalidElectrumServerUrlException extends ElectrumServerException {
  final String url;

  InvalidElectrumServerUrlException(this.url)
    : super('Invalid Electrum server URL: $url. Expected format: host:port or protocol://host:port');
}
