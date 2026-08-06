import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter/widgets.dart';

extension SwapFailureL10n on SwapFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SwapAmountOutOfBoundsFailure(
      limitAmountSat: final limit?,
      isMinimum: true,
    ) =>
      context.loc.swapErrorAmountBelowMinimum(limit.toString()),
    SwapAmountOutOfBoundsFailure(
      limitAmountSat: final limit?,
      isMinimum: false,
    ) =>
      context.loc.swapErrorAmountAboveMaximum(limit.toString()),
    SwapAmountOutOfBoundsFailure() ||
    SwapNoPaymentOptionFailure() ||
    SwapValidationFailure() ||
    SwapOrderNotFoundFailure() ||
    SwapOrderExpiredFailure() ||
    SwapCreationUnknownFailure() ||
    SwapInvalidStateFailure() ||
    SwapRateLimitedFailure() ||
    SwapProviderFailure() ||
    SwapStorageFailure() ||
    SwapUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
    SwapNetworkFailure() || SwapTimeoutFailure() => context.loc.payNetworkError,
  };
}
