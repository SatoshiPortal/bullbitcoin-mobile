import 'package:bb_mobile/features/autoswap/domain/auto_swap.dart';
import 'package:bb_mobile/features/autoswap/domain/auto_swap_settings_repository.dart';

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
