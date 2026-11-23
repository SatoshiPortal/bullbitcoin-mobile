import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/buy/domain/buy_failure.dart';
import 'package:flutter/widgets.dart';

extension BuyFailureL10n on BuyFailure {
  String toTranslated(BuildContext context) => switch (this) {
    BuyUnsupportedNetworkFailure() => context.loc.networkFeatureUnavailable,
    BuyUnauthenticatedFailure() => context.loc.buyUnauthenticatedError,
    BuyBelowMinAmountFailure() => context.loc.buyBelowMinAmountError,
    BuyAboveMaxAmountFailure() => context.loc.buyAboveMaxAmountError,
    BuyQuoteExpiredFailure() => context.loc.buyQuoteExpiredError,
    BuyQuoteUnavailableFailure() => context.loc.exchangeQuoteUnavailableError,

    // Never `logMessage`: the raw reason is logged at the boundary and is
    // never fit to show a user.
    BuyConfirmOutcomeUnknownFailure() || BuyAccelerateOutcomeUnknownFailure() =>
      context.loc.exchangeOrderActionOutcomeUnknownError,
    BuyUnexpectedFailure() => context.loc.buyUnexpectedError,
  };
}
