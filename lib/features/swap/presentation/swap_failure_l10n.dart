import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/localization/payment_network_l10n.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show BitcoinSpendStatus;
import 'package:flutter/widgets.dart';

extension SwapFailureL10n on SwapFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SwapSpendBlockedFailure(:final status) =>
      status == BitcoinSpendStatus.busy
          ? context.loc.walletSpendBusy
          : context.loc.walletSpendAwaitingObservation,
    SwapUnsupportedNetworkFailure() => context.loc.networkFeatureUnavailable,
    SwapRelaunchRequiredFailure() => context.loc.networkRelaunchRequiredError,
    SwapServerBusyFailure() => context.loc.swapServerBusyError,
    SwapLockupPendingFailure() =>
      context.loc.broadcastSignedTxErrorOutcomeUnknown,
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
    SwapNoPaymentOptionFailure(:final inNetwork?, :final outNetwork?) =>
      context.loc.swapErrorRouteUnavailable(
        inNetwork.toTranslated(context),
        outNetwork.toTranslated(context),
      ),
    SwapNoPaymentOptionFailure() =>
      context.loc.swapErrorRouteUnavailableGeneric,
    SwapSourceWalletMissingFailure() =>
      context.loc.swapValidationSelectFromWallet,
    SwapInvalidExternalAddressFailure(expectsBitcoin: true) =>
      context.loc.swapErrorInvalidBitcoinAddress,
    SwapInvalidExternalAddressFailure(expectsBitcoin: false) =>
      context.loc.swapErrorInvalidLiquidAddress,
    SwapAmountOutOfBoundsFailure() ||
    SwapValidationFailure() ||
    SwapOrderNotFoundFailure() ||
    SwapOrderExpiredFailure() ||
    SwapCreationUnknownFailure() ||
    SwapOrderMismatchFailure() ||
    SwapInvalidStateFailure() ||
    SwapProviderFailure() ||
    SwapStorageFailure() ||
    SwapUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
    SwapRateLimitedFailure(:final retryAfter) =>
      context.loc.swapErrorRateLimited(retryAfter?.inSeconds ?? 30),
    SwapNetworkFailure() || SwapTimeoutFailure() => context.loc.payNetworkError,
    SwapPriceUnavailableFailure() =>
      context.loc.bitcoinPriceExchangeRateUnavailable,
  };
}
