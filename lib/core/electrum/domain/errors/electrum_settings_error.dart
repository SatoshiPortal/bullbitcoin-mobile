sealed class ElectrumServerSettingsError extends Error {
  final String message;

  ElectrumServerSettingsError(this.message);

  @override
  String toString() => message;
}

class InvalidStopGapError extends ElectrumServerSettingsError {
  final int value;

  InvalidStopGapError(this.value)
      : super('stopGap must be non-negative, got: $value');
}

class InvalidTimeoutError extends ElectrumServerSettingsError {
  final int value;

  InvalidTimeoutError(this.value)
      : super('timeout must be positive, got: $value');
}

class InvalidRetryError extends ElectrumServerSettingsError {
  final int value;

  InvalidRetryError(this.value)
      : super('retry must be non-negative, got: $value');
}
