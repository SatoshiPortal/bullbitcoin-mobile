import 'package:swap_feature/src/swap_l10n.dart';
import 'package:swap_feature/src/ui/payment_network_l10n.dart';
import 'package:swaps/order_swaps.dart';
import 'package:sync/sync.dart' show BitcoinSpendStatus;
import 'package:flutter/widgets.dart';

extension SwapFailureL10n on SwapFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SwapSpendBlockedFailure(:final status) =>
      status == BitcoinSpendStatus.busy
          ? context.swapCopyForLocale.walletSpendBusy
          : context.swapCopyForLocale.walletSpendAwaitingObservation,
    SwapUnsupportedNetworkFailure() =>
      context.swapCopyForLocale.networkFeatureUnavailable,
    SwapRelaunchRequiredFailure() =>
      context.swapCopyForLocale.networkRelaunchRequiredError,
    SwapLockupPendingFailure() =>
      context.swapCopyForLocale.broadcastSignedTxErrorOutcomeUnknown,
    SwapAmountOutOfBoundsFailure(
      limitAmountSat: final limit?,
      isMinimum: true,
    ) =>
      context.swapCopyForLocale.swapErrorAmountBelowMinimum(limit.toString()),
    SwapAmountOutOfBoundsFailure(
      limitAmountSat: final limit?,
      isMinimum: false,
    ) =>
      context.swapCopyForLocale.swapErrorAmountAboveMaximum(limit.toString()),
    SwapNoPaymentOptionFailure(:final inNetwork?, :final outNetwork?) =>
      context.swapCopyForLocale.swapErrorRouteUnavailable(
        inNetwork.toTranslated(context),
        outNetwork.toTranslated(context),
      ),
    SwapNoPaymentOptionFailure() =>
      context.swapCopyForLocale.swapErrorRouteUnavailableGeneric,
    SwapSourceWalletMissingFailure() =>
      context.swapCopyForLocale.swapValidationSelectFromWallet,
    SwapInvalidExternalAddressFailure(expectsBitcoin: true) =>
      context.swapCopyForLocale.swapErrorInvalidBitcoinAddress,
    SwapInvalidExternalAddressFailure(expectsBitcoin: false) =>
      context.swapCopyForLocale.swapErrorInvalidLiquidAddress,
    SwapAmountOutOfBoundsFailure() ||
    SwapValidationFailure() ||
    SwapOrderNotFoundFailure() ||
    SwapOrderExpiredFailure() ||
    SwapCreationUnknownFailure() ||
    SwapOrderMismatchFailure() ||
    SwapInvalidStateFailure() ||
    SwapProviderFailure() ||
    SwapStorageFailure() ||
    SwapUnexpectedFailure() => context.swapCopyForLocale.oopsSomethingWentWrong,
    SwapRateLimitedFailure(:final retryAfter) =>
      context.swapCopyForLocale.swapErrorRateLimited(
        retryAfter?.inSeconds ?? 30,
      ),
    SwapNetworkFailure() ||
    SwapTimeoutFailure() => context.swapCopyForLocale.payNetworkError,
    SwapPriceUnavailableFailure() =>
      context.swapCopyForLocale.bitcoinPriceExchangeRateUnavailable,
  };
}
