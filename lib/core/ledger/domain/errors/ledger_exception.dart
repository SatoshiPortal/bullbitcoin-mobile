/// Low-level, thrown signals raised by the ledger datasource for semantic
/// conditions it detects itself (no device, wrong device, no permission, …).
///
/// These are `Exception`s, not [Failure]s: they are thrown inside the data
/// layer and caught once at the repository boundary, which maps them to a
/// `LedgerFailure`. They carry NO user-facing message — translation is the
/// presentation layer's job. Raw SDK/device errors are not modeled here; they
/// propagate as plain objects and the repository interprets them.
sealed class LedgerException implements Exception {
  const LedgerException();
}

final class PermissionDeniedLedgerException extends LedgerException {
  const PermissionDeniedLedgerException();
}

final class NoDevicesFoundLedgerException extends LedgerException {
  const NoDevicesFoundLedgerException();
}

final class MultipleDevicesFoundLedgerException extends LedgerException {
  const MultipleDevicesFoundLedgerException();
}

final class DeviceNotFoundLedgerException extends LedgerException {
  const DeviceNotFoundLedgerException();
}

final class ConnectionTypeNotInitializedLedgerException
    extends LedgerException {
  const ConnectionTypeNotInitializedLedgerException();
}

final class NoActiveConnectionLedgerException extends LedgerException {
  const NoActiveConnectionLedgerException();
}

final class DeviceMismatchLedgerException extends LedgerException {
  const DeviceMismatchLedgerException();
}

final class InvalidMagicBytesLedgerException extends LedgerException {
  const InvalidMagicBytesLedgerException();
}
