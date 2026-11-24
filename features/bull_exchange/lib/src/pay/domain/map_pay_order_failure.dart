import 'package:exchange/exchange.dart';

import 'pay_failure.dart';

PayFailure mapPayOrderFailure(ExchangeFailure failure) => switch (failure) {
  ExchangeNotAuthenticatedFailure() ||
  ExchangeSessionRejectedFailure() => const PayUnauthenticatedFailure(),
  ExchangeUnsupportedNetworkFailure() => const PayUnsupportedNetworkFailure(),
  ExchangeOrderLimitFailure(
    bound: ExchangeOrderAmountBound.minimum,
    :final amount,
    :final currency,
  ) =>
    PayBelowMinAmountFailure(minAmount: amount, currency: currency),
  ExchangeOrderLimitFailure(
    bound: ExchangeOrderAmountBound.maximum,
    :final amount,
    :final currency,
  ) =>
    PayAboveMaxAmountFailure(maxAmount: amount, currency: currency),
  _ => PayUnexpectedFailure(failure.logMessage),
};
