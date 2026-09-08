import 'package:bb_mobile/features/autoswap/domain/auto_swap.dart';
import 'package:bb_mobile/features/autoswap/domain/auto_swap_settings_repository.dart';

class SaveAutoSwapSettingsUsecase {
  final AutoSwapSettingsRepository _repository;

  SaveAutoSwapSettingsUsecase({required this._repository});

  Future<void> execute(AutoSwap params) async {
    await _repository.updateAutoSwapParams(params);
  }
}
