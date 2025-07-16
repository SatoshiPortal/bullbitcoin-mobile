import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';

class GetAutoSwapSettingsUsecase {
  final BoltzSwapRepository _mainnetRepository;
  final BoltzSwapRepository _testnetRepository;

  GetAutoSwapSettingsUsecase({
    required BoltzSwapRepository mainnetRepository,
    required BoltzSwapRepository testnetRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository;

  Future<AutoSwap> execute({required bool isTestnet}) async {
    final repository = isTestnet ? _testnetRepository : _mainnetRepository;
    return await repository.getAutoSwapParams();
  }
}
