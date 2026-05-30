sealed class TrezorApplicationError implements Exception {
  const TrezorApplicationError();

  const factory TrezorApplicationError.userRejected() = TrezorUserRejected;
  const factory TrezorApplicationError.suiteNotInstalled() =
      TrezorSuiteNotInstalled;
  const factory TrezorApplicationError.timeout() = TrezorTimeout;
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

final class TrezorUnknown extends TrezorApplicationError {
  final String message;
  const TrezorUnknown(this.message);
}
