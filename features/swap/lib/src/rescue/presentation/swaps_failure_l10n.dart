import '../../../generated/l10n/swap_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:swaps/swaps.dart';

extension SwapsFailureL10n on SwapsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SwapsMasterKeyUnavailableFailure() =>
      SwapLocalizations.of(context).swapsFailureMasterKeyUnavailable,
    SwapsNotRestorableFailure() => SwapLocalizations.of(context).swapsFailureNotRestorable,
    SwapsRefundNotFinalFailure() => SwapLocalizations.of(context).swapsFailureRefundNotFinal,
    SwapsNetworkFailure() ||
    SwapsBoltzUnavailableFailure() => SwapLocalizations.of(context).swapsFailureNetwork,
    SwapsBoltzRejectedFailure() ||
    SwapsAmountOutOfLimitsFailure() => SwapLocalizations.of(context).swapsFailureUnexpected,

    // Never `logMessage`: the raw reason is logged at the boundary and is
    // never fit to show a user.
    SwapsBusyFailure() ||
    SwapsAuthorizationFailure() ||
    SwapsUnsupportedNetworkFailure() ||
    SwapsInvalidServerFailure() ||
    SwapsInvalidAutoSwapSettingsFailure() ||
    SwapsInvalidLockupFailure() ||
    SwapsStorageFailure() ||
    SwapsUnexpectedFailure() ||
    AutoswapFailure() => SwapLocalizations.of(context).swapsFailureUnexpected,
  };
}
