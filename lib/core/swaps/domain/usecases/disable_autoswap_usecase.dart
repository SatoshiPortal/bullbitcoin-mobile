import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/auto_swap_settings_repository.dart';

class DisableAutoswapUsecase {
  final AutoSwapSettingsRepository _repository;

  DisableAutoswapUsecase({required this._repository});

  Future<AutoSwap> execute() async {
    final currentSettings = await _repository.getAutoSwapParams();
    final disabledSettings = currentSettings.copyWith(enabled: false);
    await _repository.updateAutoSwapParams(disabledSettings);
    return disabledSettings;
  }
}
