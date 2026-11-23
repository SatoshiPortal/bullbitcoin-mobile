import 'package:exchange/exchange.dart';

import 'sell_failure.dart';

SellFailure mapSellOrderFailure(ExchangeFailure failure) => switch (failure) {
  ExchangeNotAuthenticatedFailure() ||
  ExchangeSessionRejectedFailure() => const SellUnauthenticatedFailure(),
  ExchangeUnsupportedNetworkFailure() => const SellUnsupportedNetworkFailure(),
  ExchangeOrderLimitFailure(
    bound: ExchangeOrderAmountBound.minimum,
    :final amount,
    :final currency,
  ) =>
    SellBelowMinAmountFailure(minAmount: amount, currency: currency),
  ExchangeOrderLimitFailure(
    bound: ExchangeOrderAmountBound.maximum,
    :final amount,
    :final currency,
  ) =>
    SellAboveMaxAmountFailure(maxAmount: amount, currency: currency),
  ExchangeConfidentialSepaInactiveFailure() =>
    const SellConfidentialSepaNotActivatedFailure(),
  _ => SellUnexpectedFailure(failure.logMessage),
};
