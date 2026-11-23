import 'package:exchange/exchange.dart';

import 'withdraw_failure.dart';

WithdrawFailure mapWithdrawOrderFailure(ExchangeFailure failure) =>
    switch (failure) {
      ExchangeNotAuthenticatedFailure() || ExchangeSessionRejectedFailure() =>
        const WithdrawUnauthenticatedFailure(),
      ExchangeUnsupportedNetworkFailure() =>
        const WithdrawUnsupportedNetworkFailure(),
      ExchangeOrderLimitFailure(
        bound: ExchangeOrderAmountBound.minimum,
        :final amount,
        :final currency,
      ) =>
        WithdrawBelowMinAmountFailure(minAmount: amount, currency: currency),
      ExchangeOrderLimitFailure(
        bound: ExchangeOrderAmountBound.maximum,
        :final amount,
        :final currency,
      ) =>
        WithdrawAboveMaxAmountFailure(maxAmount: amount, currency: currency),
      ExchangeConfidentialSepaInactiveFailure() =>
        const WithdrawConfidentialSepaNotActivatedFailure(),
      _ => WithdrawUnexpectedFailure(failure.logMessage),
    };
