import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_orders_failure.dart';
import 'package:flutter/widgets.dart';

extension LimitOrdersFailureL10n on LimitOrdersFailure {
  String toTranslated(BuildContext context) => switch (this) {
    LimitOrdersUnsupportedNetworkFailure() =>
      context.loc.networkFeatureUnavailable,
    LimitOrdersAccountUnavailableFailure() =>
      context.loc.limitOrdersAccountUnavailableError,
    LimitOrdersNoFundedBalanceFailure() =>
      context.loc.limitOrdersInsufficientBalanceMessage,
    LimitOrdersMaximumActiveFailure() =>
      context.loc.limitOrdersMaximumActiveError,
    LimitOrderNotFoundFailure() => context.loc.limitOrderNotFoundError,
    LimitOrderInvalidAddressFailure() =>
      context.loc.limitOrderInvalidAddressError,
    LimitOrderInvalidTargetFailure() =>
      context.loc.limitOrderInvalidTargetError,
    LimitOrderInvalidAmountFailure() =>
      context.loc.limitOrderInvalidAmountError,
    LimitOrdersLoadFailure() => context.loc.limitOrdersLoadError,
    LimitOrderCreationFailure() => context.loc.limitOrderCreationError,
    LimitOrderCreationOutcomeUnknownFailure() =>
      context.loc.limitOrderCreationOutcomeUnknownError,
    LimitOrderCancellationFailure() => context.loc.limitOrderCancellationError,
    LimitOrdersUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
