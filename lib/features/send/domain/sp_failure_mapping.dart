import 'package:send/send.dart';
import 'package:silent/silent.dart';

extension SpFailureToSendFailure on SilentFailure {
  /// The send-side failure for the SP failures the user can act on. Null for
  /// the rest, so each wrapper picks the generic that fits its own call.
  SendFailure? toSendFailure() => switch (this) {
    SilentAmountBelowMinimum() => SendAmountOutOfBoundsFailure(
      minimumSat: BigInt.one,
      logMessage: logMessage,
    ),
    SilentAmountExceedsBalance() => SendInsufficientBalanceFailure(logMessage),
    SilentAddressNetworkMismatch() => SendAddressNetworkMismatchFailure(
      logMessage,
    ),
    SilentInvalidAddress() => SendInvalidPaymentRequestFailure(
      logMessage: logMessage,
    ),
    // Listed one by one, never a wildcard: a new SilentFailure variant must break
    // the build here rather than silently become a generic (AGENTS.md #15).
    SilentUnsupportedNetwork() ||
    SilentRequiresSuperuser() ||
    SilentRequiresDevMode() ||
    SilentNotSetUp() ||
    SilentAlreadySetUp() ||
    SilentSessionBusy() ||
    SilentScanBusy() ||
    SilentSimulationDrifted() ||
    SilentBackendUnreachable() ||
    SilentConfigInvalid() ||
    SilentSetupCleanupFailed() ||
    SilentBroadcastUncertain() ||
    SilentUnexpected() => null,
  };
}
