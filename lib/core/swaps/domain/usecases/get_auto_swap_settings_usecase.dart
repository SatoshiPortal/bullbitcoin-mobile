import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';

class GetAutoSwapSettingsUsecase {
  final BoltzSwapRepository _repository;

  GetAutoSwapSettingsUsecase({required BoltzSwapRepository repository})
    : _repository = repository;

  Future<AutoSwap> execute() async {
    return _repository.getAutoSwapParams();
  }
}
