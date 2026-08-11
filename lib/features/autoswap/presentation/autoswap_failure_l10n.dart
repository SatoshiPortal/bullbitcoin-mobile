import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:flutter/widgets.dart';

extension AutoswapFailureL10n on AutoswapFailure {
  String toTranslated(BuildContext context, {BitcoinUnit? unit}) =>
      switch (this) {
        AutoswapSettingsUnavailableFailure() =>
          context.loc.autoswapLoadSettingsError,
        AutoswapSettingsSaveFailure() =>
          context.loc.autoswapUpdateSettingsError,
        AutoswapRecipientWalletRequiredFailure() =>
          context.loc.autoswapSelectWalletError,
        AutoswapBalanceThresholdTooLowFailure(:final minimumSats) =>
          unit == BitcoinUnit.btc
              ? context.loc.autoswapMinimumThresholdErrorBtc(
                  ConvertAmount.satsToBtc(minimumSats).toString(),
                )
              : context.loc.autoswapMinimumThresholdErrorSats('$minimumSats'),
        AutoswapTriggerBalanceTooLowFailure() =>
          context.loc.autoswapTriggerBalanceError,
        AutoswapFeeThresholdTooHighFailure(:final maximumPercent) =>
          context.loc.autoswapMaximumFeeError('$maximumPercent'),
        AutoswapInvalidBoltzServerUrlFailure() =>
          context.loc.autoswapInvalidBoltzServerUrlError,
      };
}
