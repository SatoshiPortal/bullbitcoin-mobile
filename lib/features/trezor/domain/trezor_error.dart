sealed class TrezorError implements Exception {
  const TrezorError();

  const factory TrezorError.userRejected() = TrezorUserRejected;
  const factory TrezorError.suiteNotInstalled() = TrezorSuiteNotInstalled;
  const factory TrezorError.suiteUnresponsive() = TrezorSuiteUnresponsive;
  const factory TrezorError.timeout() = TrezorTimeout;
  const factory TrezorError.addressMismatch({
    required String expected,
    required String returned,
  }) = TrezorAddressMismatch;
  const factory TrezorError.missingDescriptor() = TrezorMissingDescriptor;
  const factory TrezorError.unknown(String message) = TrezorUnknown;
}

final class TrezorUserRejected extends TrezorError {
  const TrezorUserRejected();
}

final class TrezorSuiteNotInstalled extends TrezorError {
  const TrezorSuiteNotInstalled();
}

final class TrezorSuiteUnresponsive extends TrezorError {
  const TrezorSuiteUnresponsive();
}

final class TrezorTimeout extends TrezorError {
  const TrezorTimeout();
}

final class TrezorAddressMismatch extends TrezorError {
  final String expected;
  final String returned;
  const TrezorAddressMismatch({required this.expected, required this.returned});

  @override
  String toString() =>
      'TrezorAddressMismatch(expected: $expected, returned: $returned)';
}

final class TrezorMissingDescriptor extends TrezorError {
  const TrezorMissingDescriptor();
}

final class TrezorUnknown extends TrezorError {
  final String message;
  const TrezorUnknown(this.message);
}
