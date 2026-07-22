import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [SpFailure]. The only place l10n
/// touches a failure. The `sealed` switch makes a missing message a compile
/// error. Never returns the raw [Failure.logMessage]; the catch-all renders the
/// shared generic string.
extension SpFailureL10n on SpFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SpRequiresSuperuser() => context.loc.spFailureRequiresSuperuser,
    SpRequiresDevMode() => context.loc.spFailureRequiresDevMode,
    SpNotSetUp() => context.loc.spFailureNotSetUp,
    SpAlreadySetUp() => context.loc.spFailureAlreadySetUp,
    SpSessionBusy() => context.loc.spFailureSessionBusy,
    SpScanBusy() => context.loc.spFailureScanBusy,
    SpSimulationDrifted() => context.loc.spFailureSimulationDrifted,
    SpBackendUnreachable() => context.loc.spFailureBackendUnreachable,
    SpConfigInvalid() => context.loc.spFailureConfigInvalid,
    SpSetupCleanupFailed() => context.loc.spFailureSetupCleanupFailed,
    SpAmountBelowMinimum() => context.loc.spFailureAmountBelowMinimum,
    SpAmountExceedsBalance() => context.loc.spFailureAmountExceedsBalance,
    SpAddressNetworkMismatch() => context.loc.spFailureAddressNetworkMismatch,
    SpUnexpected() => context.loc.oopsSomethingWentWrong,
  };
}
