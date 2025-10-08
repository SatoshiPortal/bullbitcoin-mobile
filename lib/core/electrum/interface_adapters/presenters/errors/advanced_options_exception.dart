sealed class AdvancedOptionsException implements Exception {
  AdvancedOptionsException();
}

class InvalidStopGapException extends AdvancedOptionsException {
  final int value;

  InvalidStopGapException(this.value);
}

class InvalidTimeoutException extends AdvancedOptionsException {
  final int value;

  InvalidTimeoutException(this.value);
}

class InvalidRetryException extends AdvancedOptionsException {
  final int value;

  InvalidRetryException(this.value);
}

class SaveFailedException extends AdvancedOptionsException {
  final String? reason;

  SaveFailedException([this.reason]);
}

class UnknownException extends AdvancedOptionsException {
  final String? reason;

  UnknownException([this.reason]);
}
