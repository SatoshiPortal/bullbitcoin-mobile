import 'package:swaps/swaps.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class SaveAutoswapSettingsUsecase {
  final AutoSwapSettings _autoSwapSettings;

  const SaveAutoswapSettingsUsecase(this._autoSwapSettings);

  /// Refuses settings the entity rejects, then writes them.
  ///
  /// Validating here rather than in the caller means no future caller can
  /// persist settings that break the rules.
  @useResult
  Future<Result<void, AutoswapFailure>> execute(AutoSwap settings) async {
    final violation = settings.violation;
    if (violation != null) return Err(_failureFor(violation));

    return (await _autoSwapSettings.saveAutoSwap(settings)).mapErr(
      (failure) => switch (failure) {
        SwapsUnsupportedNetworkFailure() =>
          const AutoswapUnsupportedNetworkFailure(),
        _ => AutoswapSettingsSaveFailure(failure.logMessage),
      },
    );
  }

  AutoswapFailure _failureFor(AutoSwapSettingsViolation violation) =>
      switch (violation) {
        AutoSwapSettingsViolation.recipientWalletMissing =>
          const AutoswapRecipientWalletRequiredFailure(),
        AutoSwapSettingsViolation.balanceThresholdTooLow =>
          const AutoswapBalanceThresholdTooLowFailure(
            AutoSwap.minimumBalanceThresholdSats,
          ),
        AutoSwapSettingsViolation.triggerBalanceTooLow =>
          const AutoswapTriggerBalanceTooLowFailure(),
        AutoSwapSettingsViolation.feeThresholdTooHigh =>
          const AutoswapFeeThresholdTooHighFailure(
            AutoSwap.maximumFeeThresholdPercent,
          ),
      };
}
