import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';

extension SpFailureToSendFailure on SpFailure {
  /// The send-side failure for the SP failures the user can act on. Null for
  /// the rest, so each wrapper picks the generic that fits its own call.
  SendFailure? toSendFailure() => switch (this) {
    SpAmountBelowMinimum() => SendAmountOutOfBoundsFailure(
      minimumSat: BigInt.one,
      logMessage: logMessage,
    ),
    SpAmountExceedsBalance() => SendInsufficientBalanceFailure(logMessage),
    SpAddressNetworkMismatch() => SendAddressNetworkMismatchFailure(logMessage),
    SpInvalidAddress() => SendInvalidPaymentRequestFailure(
      logMessage: logMessage,
    ),
    // Listed one by one, never a wildcard: a new SpFailure variant must break
    // the build here rather than silently become a generic (AGENTS.md #15).
    SpRequiresSuperuser() ||
    SpRequiresDevMode() ||
    SpNotSetUp() ||
    SpAlreadySetUp() ||
    SpSessionBusy() ||
    SpScanBusy() ||
    SpSimulationDrifted() ||
    SpBackendUnreachable() ||
    SpConfigInvalid() ||
    SpSetupCleanupFailed() ||
    SpBroadcastUncertain() ||
    SpUnexpected() => null,
  };
}
