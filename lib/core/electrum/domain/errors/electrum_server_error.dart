sealed class ElectrumServerError extends Error {
  final String message;

  ElectrumServerError(this.message);

  @override
  String toString() => message;
}

class InvalidPriorityError extends ElectrumServerError {
  final int value;

  InvalidPriorityError(this.value)
    : super('priority must be non-negative, got: $value');
}

class InvalidElectrumServerUrlError extends ElectrumServerError {
  final String url;

  InvalidElectrumServerUrlError(this.url)
    : super('Invalid Electrum server URL: $url. Expected format: host:port or protocol://host:port');
}
