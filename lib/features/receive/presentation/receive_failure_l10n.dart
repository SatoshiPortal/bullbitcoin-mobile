import 'package:bb_mobile/core/primitives/payment_network_l10n.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:flutter/widgets.dart';

extension ReceiveFailureL10n on ReceiveFailure {
  String toTranslated(BuildContext context) => switch (this) {
    ReceiveAmountOutOfBoundsFailure(
      limitAmountSat: final limit?,
      isMinimum: true,
    ) =>
      context.loc.swapErrorAmountBelowMinimum(limit.toString()),
    ReceiveAmountOutOfBoundsFailure(
      limitAmountSat: final limit?,
      isMinimum: false,
    ) =>
      context.loc.swapErrorAmountAboveMaximum(limit.toString()),
    ReceiveAmountOutOfBoundsFailure() ||
    ReceiveInvalidInvoiceFailure() ||
    ReceiveSwapUnavailableFailure() ||
    ReceiveUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
    ReceiveSwapRouteUnavailableFailure(:final inNetwork?, :final outNetwork?) =>
      context.loc.swapErrorRouteUnavailable(
        inNetwork.toTranslated(context),
        outNetwork.toTranslated(context),
      ),
    ReceiveSwapRouteUnavailableFailure() =>
      context.loc.swapErrorRouteUnavailableGeneric,
    ReceiveRateLimitedFailure(:final retryAfter) =>
      context.loc.swapErrorRateLimited(retryAfter?.inSeconds ?? 30),
    ReceiveNetworkFailure() => context.loc.payNetworkError,
  };
}
