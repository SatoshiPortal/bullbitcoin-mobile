import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:flutter/widgets.dart';

extension WithdrawFailureL10n on WithdrawFailure {
  String toTranslated(BuildContext context) => switch (this) {
    WithdrawUnauthenticatedFailure() =>
      context.loc.withdrawUnauthenticatedError,
    WithdrawBelowMinAmountFailure() => context.loc.withdrawBelowMinAmountError,
    WithdrawAboveMaxAmountFailure() => context.loc.withdrawAboveMaxAmountError,

    // Never `logMessage`: the raw reason is logged at the boundary and is
    // never fit to show a user. The copy stays actionable — "try again or
    // contact support" — rather than a bare "something went wrong", matching
    // `buyUnexpectedError` and `sellUnexpectedError`.
    WithdrawUnexpectedFailure() => context.loc.withdrawUnexpectedError,
  };
}
