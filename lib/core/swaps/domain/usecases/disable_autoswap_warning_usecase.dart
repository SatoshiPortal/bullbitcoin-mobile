import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';

class DisableAutoswapWarningUsecase {
  final BoltzSwapRepository _repository;

  DisableAutoswapWarningUsecase({required BoltzSwapRepository repository})
    : _repository = repository;

  Future<AutoSwap> execute() async {
    final currentSettings = await _repository.getAutoSwapParams();
    final disabledWarningSettings = currentSettings.copyWith(
      showWarning: false,
    );
    await _repository.updateAutoSwapParams(disabledWarningSettings);
    return disabledWarningSettings;
  }
}
