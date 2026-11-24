import 'package:primitives/primitives.dart' show BitcoinUnit, ConvertAmount;
import 'package:swap_feature/src/swap_l10n.dart';
import 'package:swaps/swaps.dart';
import 'package:flutter/widgets.dart';

extension AutoswapFailureL10n on AutoswapFailure {
  String toTranslated(BuildContext context, {BitcoinUnit? unit}) =>
      switch (this) {
        AutoswapUnsupportedNetworkFailure() =>
          context.swapCopyForLocale.networkFeatureUnavailable,
        AutoswapSettingsUnavailableFailure() =>
          context.swapCopyForLocale.autoswapLoadSettingsError,
        AutoswapSettingsSaveFailure() =>
          context.swapCopyForLocale.autoswapUpdateSettingsError,
        AutoswapRecipientWalletRequiredFailure() =>
          context.swapCopyForLocale.autoswapSelectWalletError,
        AutoswapBalanceThresholdTooLowFailure(:final minimumSats) =>
          unit == BitcoinUnit.btc
              ? context.swapCopyForLocale.autoswapMinimumThresholdErrorBtc(
                  ConvertAmount.satsToBtc(minimumSats).toString(),
                )
              : context.swapCopyForLocale.autoswapMinimumThresholdErrorSats(
                  '$minimumSats',
                ),
        AutoswapTriggerBalanceTooLowFailure() =>
          context.swapCopyForLocale.autoswapTriggerBalanceError,
        AutoswapFeeThresholdTooHighFailure(:final maximumPercent) =>
          context.swapCopyForLocale.autoswapMaximumFeeError('$maximumPercent'),
        AutoswapDisabledFailure() ||
        AutoswapInvalidSettingsFailure() ||
        AutoswapNoWalletFailure() ||
        AutoswapUnsupportedWalletFailure() ||
        AutoswapInsufficientBalanceFailure() ||
        AutoswapFeeLimitExceededFailure() ||
        AutoswapProviderFailure() ||
        AutoswapExecutionFailure() ||
        AutoswapPendingFailure() ||
        AutoswapPayinMismatchFailure() ||
        AutoswapTargetBalanceFailure() ||
        AutoswapAmountOutOfBoundsFailure() ||
        AutoswapBoltzUnavailableFailure() =>
          context.swapCopyForLocale.oopsSomethingWentWrong,
      };
}
