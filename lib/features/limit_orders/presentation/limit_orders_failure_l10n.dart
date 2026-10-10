import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:flutter/widgets.dart';

extension LimitOrdersFailureL10n on LimitOrdersFailure {
  String toTranslated(BuildContext context) => switch (this) {
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
    LimitOrderCancellationFailure() => context.loc.limitOrderCancellationError,
    LimitOrdersUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
