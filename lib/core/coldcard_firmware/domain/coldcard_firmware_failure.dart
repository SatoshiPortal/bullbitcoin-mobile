import 'package:bb_mobile/core/failures/failure.dart';

/// Failures of the Coldcard firmware update flow. Any of these means no verified firmware: the UI must fail closed (no checkmark, no export).
sealed class ColdcardFirmwareFailure extends Failure {
  const ColdcardFirmwareFailure([super.logMessage]);
}

/// The firmware server or the manifest could not be reached.
final class ColdcardFirmwareNetworkFailure extends ColdcardFirmwareFailure {
  const ColdcardFirmwareNetworkFailure([super.logMessage]);
}

/// The latest release could not be determined (page layout changed, nothing offered for the model, or an oversized response was refused).
final class ColdcardFirmwareDiscoveryFailure extends ColdcardFirmwareFailure {
  const ColdcardFirmwareDiscoveryFailure([super.logMessage]);
}

/// The downloaded firmware failed integrity verification (bad manifest signature, wrong signing key, hash mismatch, or a file not listed in the signed manifest). The bytes were discarded.
final class ColdcardFirmwareVerificationFailure
    extends ColdcardFirmwareFailure {
  const ColdcardFirmwareVerificationFailure([super.logMessage]);
}

/// The verified firmware could not be written to the destination the user picked.
final class ColdcardFirmwareSaveFailure extends ColdcardFirmwareFailure {
  const ColdcardFirmwareSaveFailure([super.logMessage]);
}

/// Anything unexpected; the log message carries the detail for us, the user gets a generic message.
final class ColdcardFirmwareUnexpectedFailure extends ColdcardFirmwareFailure {
  const ColdcardFirmwareUnexpectedFailure([super.logMessage]);
}
