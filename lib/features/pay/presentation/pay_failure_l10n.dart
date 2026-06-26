import 'package:bb_mobile/core/exchange/domain/failures/pay_failure.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

extension PayFailureL10n on PayFailure {
  String toTranslated(BuildContext context) => switch (this) {
        PayUnauthenticatedFailure() => context.loc.payNotAuthenticated,
        PayBelowMinAmountFailure(:final minAmountSat) =>
          context.loc.payBelowMinAmount(minAmountSat),
        PayAboveMaxAmountFailure(:final maxAmountSat) =>
          context.loc.payAboveMaxAmount(maxAmountSat),
        PayInsufficientBalanceFailure() => context.loc.payInsufficientBalance,
        PayUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
      };
}
