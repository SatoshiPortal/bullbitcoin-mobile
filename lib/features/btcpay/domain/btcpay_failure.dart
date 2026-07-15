import 'package:bb_mobile/core/failures/failure.dart';

/// Typed, recoverable failures exposed by the BTCPay feature.
///
/// [logMessage] is diagnostic-only. Presentation maps the closed failure set
/// to localized copy and never renders server or exception text.
sealed class BtcpayFailure extends Failure {
  const BtcpayFailure([super.logMessage]);
}

final class InvalidBtcpayPairingRequestFailure extends BtcpayFailure {
  const InvalidBtcpayPairingRequestFailure([super.logMessage]);
}

final class BtcpayPairingRejectedFailure extends BtcpayFailure {
  const BtcpayPairingRejectedFailure([super.logMessage]);
}

/// Descriptor submission may have reached the server, but completion was not
/// confirmed. The user must inspect the server before retrying.
final class BtcpayPairingUncertainFailure extends BtcpayFailure {
  const BtcpayPairingUncertainFailure([super.logMessage]);
}

final class BtcpayWalletPreparationFailure extends BtcpayFailure {
  const BtcpayWalletPreparationFailure([super.logMessage]);
}

/// Dedicated wallets were materialized, but the durable local setup did not
/// complete before any descriptor was submitted.
final class BtcpayLocalSetupFailure extends BtcpayFailure {
  const BtcpayLocalSetupFailure([super.logMessage]);
}

/// Existing recovery metadata disagrees with the prepared BTCPay wallets.
final class BtcpayKeychainConflictFailure extends BtcpayFailure {
  const BtcpayKeychainConflictFailure([super.logMessage]);
}

final class BtcpayPayloadFailure extends BtcpayFailure {
  const BtcpayPayloadFailure([super.logMessage]);
}

final class BtcpayStorageFailure extends BtcpayFailure {
  const BtcpayStorageFailure([super.logMessage]);
}

final class BtcpayRollbackFailure extends BtcpayFailure {
  const BtcpayRollbackFailure([super.logMessage]);
}

final class BtcpayUnexpectedFailure extends BtcpayFailure {
  const BtcpayUnexpectedFailure([super.logMessage]);
}
