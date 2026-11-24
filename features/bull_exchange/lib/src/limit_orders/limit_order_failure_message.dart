import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

import '../exchange_l10n.dart';

extension LimitOrderFailureMessage on ExchangeFailure {
  String toLimitOrderMessage(BuildContext context) => switch (this) {
    ExchangeNotAuthenticatedFailure() || ExchangeSessionRejectedFailure() =>
      context.loc.limitOrdersAccountUnavailableError,
    ExchangeUnsupportedNetworkFailure() =>
      context.loc.networkFeatureUnavailable,
    ExchangeLimitOrderFailure(:final problem) => switch (problem) {
      ExchangeLimitOrderProblem.load => context.loc.limitOrdersLoadError,
      ExchangeLimitOrderProblem.cancel =>
        context.loc.limitOrderCancellationError,
      ExchangeLimitOrderProblem.notFound => context.loc.limitOrderNotFoundError,
      ExchangeLimitOrderProblem.create => context.loc.limitOrderCreationError,
      ExchangeLimitOrderProblem.createOutcomeUnknown =>
        context.loc.limitOrderCreationOutcomeUnknownError,
      ExchangeLimitOrderProblem.maximumActive =>
        context.loc.limitOrdersMaximumActiveError,
      ExchangeLimitOrderProblem.invalidAddress =>
        context.loc.limitOrderInvalidAddressError,
    },
    _ => context.loc.oopsSomethingWentWrong,
  };
}
