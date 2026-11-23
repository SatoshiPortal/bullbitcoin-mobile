import 'package:exchange/exchange.dart';

import 'buy_failure.dart';

BuyFailure mapBuyOrderFailure(ExchangeFailure failure) => switch (failure) {
  ExchangeNotAuthenticatedFailure() ||
  ExchangeSessionRejectedFailure() => const BuyUnauthenticatedFailure(),
  ExchangeUnsupportedNetworkFailure() => const BuyUnsupportedNetworkFailure(),
  ExchangeOrderLimitFailure(
    bound: ExchangeOrderAmountBound.minimum,
    :final amount,
    :final currency,
  ) =>
    BuyBelowMinAmountFailure(minAmount: amount, currency: currency),
  ExchangeOrderLimitFailure(
    bound: ExchangeOrderAmountBound.maximum,
    :final amount,
    :final currency,
  ) =>
    BuyAboveMaxAmountFailure(maxAmount: amount, currency: currency),
  _ => BuyUnexpectedFailure(failure.logMessage),
};
