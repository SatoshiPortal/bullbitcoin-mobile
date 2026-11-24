import 'package:send/src/send_localizations.dart';
import 'package:send/src/payment/presentation/payment_network_l10n.dart';
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:flutter/widgets.dart';

extension SendFailureL10n on SendFailure {
  String toTranslated(
    BuildContext context, {
    String? formattedFrozenBalance,
  }) => switch (this) {
    SendPayjoinUnavailableFailure() => context.loc.appStartupErrorMessage,
    SendPayjoinPausedFailure() => context.loc.sendPayjoinSpendPaused,
    SendSpendBlockedFailure(:final busy) =>
      busy
          ? context.loc.walletSpendBusy
          : context.loc.walletSpendAwaitingObservation,
    SendInvalidPaymentRequestFailure(:final isUnsupportedQr) =>
      isUnsupportedQr
          ? context.loc.sendErrorUnsupportedQrCodeFormat
          : context.loc.sendErrorInvalidAddressOrInvoice,
    SendInvoiceExpiredFailure() => context.loc.sendErrorInvoiceExpired,
    SendInvoiceExpiryTooShortFailure() =>
      context.loc.sendErrorInvoiceExpiryTooShort,
    SendInvoiceAmountRequiredFailure() =>
      context.loc.sendErrorInvoiceMustContainAmount,
    SendLnurlLimitsUnavailableFailure() =>
      context.loc.sendLnurlLimitsUnavailable,
    SendLnurlNoPayableAmountFailure() => context.loc.sendLnurlNoPayableAmount,
    SendLnurlAmountOutOfBoundsFailure(:final minimumSat, :final maximumSat) =>
      context.loc.sendLnurlAmountRange(minimumSat, maximumSat),
    SendHardwareWalletFailure() =>
      context.loc.sendErrorHardwareWalletCannotSwap,
    SendInsufficientBalanceFailure() =>
      formattedFrozenBalance == null
          ? context.loc.sendErrorInsufficientBalanceForPayment
          : context.loc.sendErrorInsufficientBalanceFrozenHint(
              formattedFrozenBalance,
            ),
    SendAddressNetworkMismatchFailure() =>
      context.loc.sendErrorAddressNetworkMismatch,
    SendInsufficientFundsForFeesFailure() =>
      context.loc.sendErrorInsufficientFundsForFees,
    SendRelaunchRequiredFailure() => context.loc.networkRelaunchRequiredError,
    SendSelectedCoinsUnavailableFailure() =>
      context.loc.sendErrorSelectedCoinsUnavailable,
    SendSelectedCoinsInsufficientFailure() =>
      context.loc.sendErrorSelectedCoinsInsufficient,
    SendAmountOutOfBoundsFailure(:final minimumSat?) =>
      context.loc.sendErrorAmountBelowMinimum(minimumSat.toString()),
    SendAmountOutOfBoundsFailure(:final maximumSat?) =>
      context.loc.sendErrorAmountAboveMaximum(maximumSat.toString()),
    SendAmountOutOfBoundsFailure() =>
      context.loc.sendErrorAmountBelowSwapLimits,
    SendSwapCreationFailure() => context.loc.sendErrorSwapCreationFailed,
    SendSwapRouteUnavailableFailure(:final inNetwork?, :final outNetwork?) =>
      context.loc.swapErrorRouteUnavailable(
        inNetwork.toTranslated(context),
        outNetwork.toTranslated(context),
      ),
    SendSwapRouteUnavailableFailure() =>
      context.loc.swapErrorRouteUnavailableGeneric,
    SendRateLimitedFailure(:final retryAfter) =>
      context.loc.swapErrorRateLimited(retryAfter?.inSeconds ?? 30),
    SendConsolidationRequiredFailure() ||
    SendTransactionBuildFailure() => context.loc.sendErrorBuildFailed,
    SendFeeBelowRelayFloorFailure() => context.loc.sendErrorFeeBelowRelayFloor,
    SendFeesUnavailableFailure() => context.loc.sendErrorFeesUnavailable,
    SendExchangeOrderMismatchFailure() =>
      context.loc.sendErrorExchangeOrderMismatch,
    SendTransactionConfirmationFailure(:final isBroadcastFailure) =>
      isBroadcastFailure
          ? context.loc.sendErrorBroadcastFailed
          : context.loc.sendErrorConfirmationFailed,
    SendPriceUnavailableFailure() =>
      context.loc.bitcoinPriceExchangeRateUnavailable,
    SendArkRouteUnavailableFailure() ||
    SendUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
