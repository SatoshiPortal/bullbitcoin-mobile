import 'package:silent/src/presentation/silent_l10n.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [SilentFailure]. The only place l10n
/// touches a failure. The `sealed` switch makes a missing message a compile
/// error. Never returns the raw [Failure.logMessage]; the catch-all renders the
/// shared generic string.
extension SpFailureL10n on SilentFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SilentRequiresSuperuser() =>
      context.silentLoc.silentFailureRequiresSuperuser,
    SilentRequiresDevMode() => context.silentLoc.silentFailureRequiresDevMode,
    SilentNotSetUp() => context.silentLoc.silentFailureNotSetUp,
    SilentAlreadySetUp() => context.silentLoc.silentFailureAlreadySetUp,
    SilentSessionBusy() => context.silentLoc.silentFailureSessionBusy,
    SilentScanBusy() => context.silentLoc.silentFailureScanBusy,
    SilentSimulationDrifted() =>
      context.silentLoc.silentFailureSimulationDrifted,
    SilentBackendUnreachable() =>
      context.silentLoc.silentFailureBackendUnreachable,
    SilentConfigInvalid() => context.silentLoc.silentFailureConfigInvalid,
    SilentSetupCleanupFailed() =>
      context.silentLoc.silentFailureSetupCleanupFailed,
    SilentBackendRollbackFailed() =>
      context.silentLoc.silentFailureBackendRollbackFailed,
    SilentAmountBelowMinimum() =>
      context.silentLoc.silentFailureAmountBelowMinimum,
    SilentAmountExceedsBalance() =>
      context.silentLoc.silentFailureAmountExceedsBalance,
    SilentAddressNetworkMismatch() =>
      context.silentLoc.silentFailureAddressNetworkMismatch,
    SilentInvalidAddress() => context.silentLoc.silentFailureInvalidAddress,
    SilentBroadcastUncertain() =>
      context.silentLoc.silentFailureBroadcastUncertain,
    SilentUnsupportedNetwork() => context.silentLoc.oopsSomethingWentWrong,
    SilentUnexpected() => context.silentLoc.oopsSomethingWentWrong,
  };
}
