import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';
import 'package:boltz_swaps/boltz_swaps.dart';

extension SwapsFailureL10n on SwapsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SwapsMasterKeyUnavailableFailure() =>
      context.loc.swapsFailureMasterKeyUnavailable,
    SwapsNotRestorableFailure() => context.loc.swapsFailureNotRestorable,
    SwapsRefundNotFinalFailure() => context.loc.swapsFailureRefundNotFinal,
    SwapsNetworkFailure() => context.loc.swapsFailureNetwork,

    // Never `logMessage`: the raw reason is logged at the boundary and is
    // never fit to show a user.
    SwapsUnexpectedFailure() => context.loc.swapsFailureUnexpected,
  };
}
