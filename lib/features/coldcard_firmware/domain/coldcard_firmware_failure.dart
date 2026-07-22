import 'package:bb_mobile/core/failures/failure.dart';

/// Failures of the Coldcard firmware update flow.
sealed class ColdcardFirmwareFailure extends Failure {
  const ColdcardFirmwareFailure([super.logMessage]);
}

/// The firmware server or signed manifest could not be reached.
final class ColdcardFirmwareNetworkFailure extends ColdcardFirmwareFailure {
  const ColdcardFirmwareNetworkFailure([super.logMessage]);
}

/// The latest release could not be determined.
final class ColdcardFirmwareDiscoveryFailure extends ColdcardFirmwareFailure {
  const ColdcardFirmwareDiscoveryFailure([super.logMessage]);
}

/// Firmware verification failed, or no verified firmware is available.
final class ColdcardFirmwareVerificationFailure
    extends ColdcardFirmwareFailure {
  const ColdcardFirmwareVerificationFailure([super.logMessage]);
}

/// Verified firmware could not be written to the selected destination.
final class ColdcardFirmwareSaveFailure extends ColdcardFirmwareFailure {
  const ColdcardFirmwareSaveFailure([super.logMessage]);
}

/// An unexpected recoverable exception crossed the data boundary.
final class ColdcardFirmwareUnexpectedFailure extends ColdcardFirmwareFailure {
  const ColdcardFirmwareUnexpectedFailure([super.logMessage]);
}
