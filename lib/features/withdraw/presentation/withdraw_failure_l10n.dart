import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:flutter/widgets.dart';

extension WithdrawFailureL10n on WithdrawFailure {
  String toTranslated(BuildContext context) => switch (this) {
    WithdrawUnauthenticatedFailure() =>
      context.loc.withdrawUnauthenticatedError,
    WithdrawBelowMinAmountFailure() => context.loc.withdrawBelowMinAmountError,
    WithdrawAboveMaxAmountFailure() => context.loc.withdrawAboveMaxAmountError,
    WithdrawOrderNotFoundFailure() => context.loc.withdrawOrderNotFoundError,
    WithdrawOrderAlreadyConfirmedFailure() =>
      context.loc.withdrawOrderAlreadyConfirmedError,
    WithdrawConfidentialSepaNotActivatedFailure() =>
      context.loc.recipientsConfidentialSepaNotActivatedError,
    WithdrawUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
