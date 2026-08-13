import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/auto_swap_settings_repository.dart';

class DisableAutoswapWarningUsecase {
  final AutoSwapSettingsRepository _repository;

  DisableAutoswapWarningUsecase({required this._repository});

  Future<AutoSwap> execute() async {
    final currentSettings = await _repository.getAutoSwapParams();
    final disabledWarningSettings = currentSettings.copyWith(
      showWarning: false,
    );
    await _repository.updateAutoSwapParams(disabledWarningSettings);
    return disabledWarningSettings;
  }
}
