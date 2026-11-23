import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/localization/payment_network_l10n.dart';
import 'package:primitives/primitives.dart' show FormatAmount;
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
    ReceiveUnexpectedFailure() ||
    ReceiveBroadcastOriginalTxVerificationFailure() =>
      context.loc.oopsSomethingWentWrong,
    ReceiveSwapRouteUnavailableFailure(:final inNetwork?, :final outNetwork?) =>
      context.loc.swapErrorRouteUnavailable(
        inNetwork.toTranslated(context),
        outNetwork.toTranslated(context),
      ),
    ReceiveUnsupportedNetworkFailure() ||
    ReceiveSwapRouteUnavailableFailure() =>
      context.loc.swapErrorRouteUnavailableGeneric,
    ReceiveRateLimitedFailure(:final retryAfter) =>
      context.loc.swapErrorRateLimited(retryAfter?.inSeconds ?? 30),
    ReceiveNetworkFailure() => context.loc.payNetworkError,
    ReceivePriceUnavailableFailure() =>
      context.loc.bitcoinPriceExchangeRateUnavailable,
    ReceiveAmountAboveProtocolLimitFailure(:final limitAmountSat) =>
      context.loc.receiveErrorAmountAboveProtocolLimit(
        FormatAmount.sats(limitAmountSat),
      ),
    ReceiveNoteNotSavedFailure() => context.loc.receiveErrorNoteNotSaved,
    ReceiveAddressUnavailableFailure() =>
      context.loc.receiveErrorAddressUnavailable,
    ReceiveBroadcastOriginalTxFailure() =>
      context.loc.receiveErrorBroadcastOriginal,
    ReceivePayjoinUnavailableFailure() => context.loc.appStartupErrorMessage,
    ReceivePayjoinSettingFailure() ||
    ReceivePayjoinPolicyUnavailableFailure() ||
    ReceiveBroadcastOriginalTxUnavailableFailure() =>
      context.loc.oopsSomethingWentWrong,
  };
}
