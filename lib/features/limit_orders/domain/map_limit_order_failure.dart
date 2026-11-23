import 'package:exchange/exchange.dart';

import 'limit_orders_failure.dart';

LimitOrdersFailure mapLimitOrderFailure(ExchangeFailure failure) =>
    switch (failure) {
      ExchangeNotAuthenticatedFailure() || ExchangeSessionRejectedFailure() =>
        LimitOrdersAccountUnavailableFailure(failure.logMessage),
      ExchangeUnsupportedNetworkFailure() =>
        const LimitOrdersUnsupportedNetworkFailure(),
      ExchangeLimitOrderFailure(:final problem, :final logMessage) =>
        switch (problem) {
          ExchangeLimitOrderProblem.load => LimitOrdersLoadFailure(logMessage),
          ExchangeLimitOrderProblem.create => LimitOrderCreationFailure(
            logMessage,
          ),
          ExchangeLimitOrderProblem.cancel => LimitOrderCancellationFailure(
            logMessage,
          ),
          ExchangeLimitOrderProblem.maximumActive =>
            LimitOrdersMaximumActiveFailure(logMessage),
          ExchangeLimitOrderProblem.notFound => LimitOrderNotFoundFailure(
            logMessage,
          ),
          ExchangeLimitOrderProblem.invalidAddress =>
            LimitOrderInvalidAddressFailure(logMessage),
        },
      _ => LimitOrdersUnexpectedFailure(failure.logMessage),
    };
