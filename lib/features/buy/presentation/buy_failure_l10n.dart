import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:flutter/widgets.dart';

extension BuyFailureL10n on BuyFailure {
  String toTranslated(BuildContext context) => switch (this) {
    BuyUnauthenticatedFailure() => context.loc.buyUnauthenticatedError,
    BuyBelowMinAmountFailure() => context.loc.buyBelowMinAmountError,
    BuyAboveMaxAmountFailure() => context.loc.buyAboveMaxAmountError,

    // Never `logMessage`: the raw reason is logged at the boundary and is
    // never fit to show a user.
    BuyUnexpectedFailure() => context.loc.buyUnexpectedError,
  };
}
