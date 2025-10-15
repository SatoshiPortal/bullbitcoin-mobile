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
  final bool isLiquid;

  InvalidElectrumServerUrlException(this.url, {required this.isLiquid})
    : super(
        'Invalid Electrum server URL: $url. Expected format: ${isLiquid ? 'host:port' : 'host:port or protocol://host:port'} with port between 1-65535',
      );
}
