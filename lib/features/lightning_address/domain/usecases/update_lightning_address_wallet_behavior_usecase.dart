import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart';

/// Lightning Address's own wrapper over the Get Paid settings boundary: persist
/// the reserved wallet (101)'s display/sweep behavior.
///
/// Reports only whether the write landed, so the caller can restore what it
/// optimistically showed. No foreign exception reaches presentation.
class UpdateLightningAddressWalletBehaviorUsecase {
  final GetPaidSettingsFacade _getPaidSettings;

  const UpdateLightningAddressWalletBehaviorUsecase({
    required this._getPaidSettings,
  });

  Future<bool> execute({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) async {
    return switch (await _getPaidSettings.updateWalletBehavior(
      walletId: walletId,
      hideOnHome: hideOnHome,
      autoSweepEnabled: autoSweepEnabled,
    )) {
      Ok() => true,
      Err() => false,
    };
  }
}
