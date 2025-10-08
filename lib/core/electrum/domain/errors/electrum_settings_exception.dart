sealed class ElectrumServerSettingsException implements Exception {
  final String message;

  ElectrumServerSettingsException(this.message);

  @override
  String toString() => message;
}

class InvalidStopGapException extends ElectrumServerSettingsException {
  final int value;

  InvalidStopGapException(this.value)
      : super('stopGap must be non-negative, got: $value');
}

class InvalidTimeoutException extends ElectrumServerSettingsException {
  final int value;

  InvalidTimeoutException(this.value)
      : super('timeout must be positive, got: $value');
}

class InvalidRetryException extends ElectrumServerSettingsException {
  final int value;

  InvalidRetryException(this.value)
      : super('retry must be non-negative, got: $value');
}
