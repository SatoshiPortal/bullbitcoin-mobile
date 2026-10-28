import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:flutter/widgets.dart';

extension BuyFailureL10n on BuyFailure {
  String toTranslated(BuildContext context) => switch (this) {
    BuyOutcomeUnknownFailure() => context.loc.buyOrderOutcomeUnknownError,
    BuyUnauthenticatedFailure() => context.loc.buyUnauthenticatedError,
    BuyBelowMinAmountFailure() => context.loc.buyBelowMinAmountError,
    BuyAboveMaxAmountFailure() => context.loc.buyAboveMaxAmountError,
    BuyQuoteExpiredFailure() => context.loc.buyQuoteExpiredError,
    BuyQuoteUnavailableFailure() => context.loc.exchangeQuoteUnavailableError,

    // Never `logMessage`: the raw reason is logged at the boundary and is
    // never fit to show a user.
    BuyUnexpectedFailure() => context.loc.buyUnexpectedError,
  };
}
