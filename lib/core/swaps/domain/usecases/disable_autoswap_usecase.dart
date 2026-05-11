import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';

class DisableAutoswapUsecase {
  final BoltzSwapRepository _repository;

  DisableAutoswapUsecase({required BoltzSwapRepository repository})
    : _repository = repository;

  Future<AutoSwap> execute() async {
    final currentSettings = await _repository.getAutoSwapParams();
    final disabledSettings = currentSettings.copyWith(enabled: false);
    await _repository.updateAutoSwapParams(disabledSettings);
    return disabledSettings;
  }
}
