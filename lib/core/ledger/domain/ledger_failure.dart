import 'package:bb_mobile/core/failures/failure.dart';

sealed class LedgerFailure extends Failure {
  const LedgerFailure([super.logMessage]);
}

/// Bluetooth (or app) permissions were denied — the only failure the UI treats
/// specially, offering a "manage permissions" shortcut.
final class LedgerPermissionDeniedFailure extends LedgerFailure {
  const LedgerPermissionDeniedFailure([super.logMessage]);
}

final class LedgerNoDevicesFoundFailure extends LedgerFailure {
  const LedgerNoDevicesFoundFailure([super.logMessage]);
}

final class LedgerMultipleDevicesFoundFailure extends LedgerFailure {
  const LedgerMultipleDevicesFoundFailure([super.logMessage]);
}

final class LedgerDeviceNotFoundFailure extends LedgerFailure {
  const LedgerDeviceNotFoundFailure([super.logMessage]);
}

final class LedgerDeviceMismatchFailure extends LedgerFailure {
  const LedgerDeviceMismatchFailure([super.logMessage]);
}

final class LedgerInvalidPsbtFailure extends LedgerFailure {
  const LedgerInvalidPsbtFailure([super.logMessage]);
}

/// The user rejected the operation on the device (APDU 6985).
final class LedgerRejectedByUserFailure extends LedgerFailure {
  const LedgerRejectedByUserFailure([super.logMessage]);
}

/// The device is locked (APDU 5515).
final class LedgerDeviceLockedFailure extends LedgerFailure {
  const LedgerDeviceLockedFailure([super.logMessage]);
}

/// The Bitcoin app is not open on the device (APDU 6e01/6a87/6d02/6511/6e00).
final class LedgerBitcoinAppNotOpenFailure extends LedgerFailure {
  const LedgerBitcoinAppNotOpenFailure([super.logMessage]);
}

/// No active connection to a device. Raised both by the datasource (when an
/// operation needs a live connection it doesn't have) and by the UI pre-check
/// before an operation is requested; both surface the same message.
final class LedgerNoConnectionFailure extends LedgerFailure {
  const LedgerNoConnectionFailure([super.logMessage]);
}

/// Another program (e.g. Ledger Live) is communicating with the device, so the
/// app cannot claim the connection. The user must close the other program.
final class LedgerDeviceBusyFailure extends LedgerFailure {
  const LedgerDeviceBusyFailure([super.logMessage]);
}

/// A required PSBT parameter was missing when signing.
final class LedgerMissingPsbtFailure extends LedgerFailure {
  const LedgerMissingPsbtFailure([super.logMessage]);
}

/// A required address parameter was missing when verifying.
final class LedgerMissingAddressFailure extends LedgerFailure {
  const LedgerMissingAddressFailure([super.logMessage]);
}

/// A required derivation path parameter was missing.
final class LedgerMissingDerivationPathFailure extends LedgerFailure {
  const LedgerMissingDerivationPathFailure([super.logMessage]);
}

/// A required script type parameter was missing.
final class LedgerMissingScriptTypeFailure extends LedgerFailure {
  const LedgerMissingScriptTypeFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI — the
/// presentation extension returns the shared generic string.
final class LedgerUnexpectedFailure extends LedgerFailure {
  const LedgerUnexpectedFailure([super.logMessage]);
}
