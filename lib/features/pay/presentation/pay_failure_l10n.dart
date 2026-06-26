import 'package:bb_mobile/core/exchange/domain/failures/pay_failure.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

extension PayFailureL10n on PayFailure {
  String toTranslated(BuildContext context) => switch (this) {
        PayUnauthenticatedFailure() => context.loc.payNotAuthenticated,
        PayBelowMinAmountFailure() => context.loc.payBelowMinAmount,
        PayAboveMaxAmountFailure() => context.loc.payAboveMaxAmount,
        PayInsufficientBalanceFailure() => context.loc.payInsufficientBalance,
        PayOrderNotFoundFailure() => context.loc.payOrderNotFound,
        PayOrderAlreadyConfirmedFailure() =>
          context.loc.payOrderAlreadyConfirmed,
        PayUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
      };
}
