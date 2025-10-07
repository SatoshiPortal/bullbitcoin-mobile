sealed class AdvancedOptionsError extends Error {
  AdvancedOptionsError();
}

class InvalidStopGapError extends AdvancedOptionsError {
  final int value;

  InvalidStopGapError(this.value);
}

class InvalidTimeoutError extends AdvancedOptionsError {
  final int value;

  InvalidTimeoutError(this.value);
}

class InvalidRetryError extends AdvancedOptionsError {
  final int value;

  InvalidRetryError(this.value);
}

class SaveFailedError extends AdvancedOptionsError {
  final String? reason;

  SaveFailedError([this.reason]);
}
