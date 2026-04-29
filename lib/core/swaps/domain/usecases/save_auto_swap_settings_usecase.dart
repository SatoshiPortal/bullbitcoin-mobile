import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';

class SaveAutoSwapSettingsUsecase {
  final BoltzSwapRepository _repository;

  SaveAutoSwapSettingsUsecase({required BoltzSwapRepository repository})
    : _repository = repository;

  Future<void> execute(AutoSwap params) async {
    await _repository.updateAutoSwapParams(params);
  }
}
