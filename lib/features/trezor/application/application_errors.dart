sealed class TrezorApplicationError implements Exception {
  const TrezorApplicationError();

  const factory TrezorApplicationError.userRejected() = TrezorUserRejected;
  const factory TrezorApplicationError.suiteNotInstalled() =
      TrezorSuiteNotInstalled;
  const factory TrezorApplicationError.timeout() = TrezorTimeout;
  const factory TrezorApplicationError.addressMismatch({
    required String expected,
    required String returned,
  }) = TrezorAddressMismatch;
  const factory TrezorApplicationError.missingDescriptor() =
      TrezorMissingDescriptor;
  const factory TrezorApplicationError.unknown(String message) = TrezorUnknown;
}

final class TrezorUserRejected extends TrezorApplicationError {
  const TrezorUserRejected();
}

final class TrezorSuiteNotInstalled extends TrezorApplicationError {
  const TrezorSuiteNotInstalled();
}

final class TrezorTimeout extends TrezorApplicationError {
  const TrezorTimeout();
}

final class TrezorAddressMismatch extends TrezorApplicationError {
  final String expected;
  final String returned;
  const TrezorAddressMismatch({required this.expected, required this.returned});

  @override
  String toString() =>
      'TrezorAddressMismatch(expected: $expected, returned: $returned)';
}

final class TrezorMissingDescriptor extends TrezorApplicationError {
  const TrezorMissingDescriptor();
}

final class TrezorUnknown extends TrezorApplicationError {
  final String message;
  const TrezorUnknown(this.message);
}
