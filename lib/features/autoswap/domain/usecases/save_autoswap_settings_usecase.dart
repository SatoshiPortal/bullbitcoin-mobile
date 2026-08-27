import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:meta/meta.dart';

class SaveAutoswapSettingsUsecase {
  final SaveAutoSwapSettingsUsecase _saveAutoSwapSettingsUsecase;

  const SaveAutoswapSettingsUsecase({
    required this._saveAutoSwapSettingsUsecase,
  });

  /// Refuses settings the entity rejects, then writes them.
  ///
  /// Validating here rather than in the caller means no future caller can
  /// persist settings that break the rules.
  @useResult
  Future<Result<void, AutoswapFailure>> execute(AutoSwap settings) async {
    final violation = settings.violation;
    if (violation != null) return Err(_failureFor(violation));

    try {
      await _saveAutoSwapSettingsUsecase.execute(settings);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to save auto swap settings',
        error: e,
        trace: st,
      );
      return Err(AutoswapSettingsSaveFailure(e.runtimeType.toString()));
    }
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
