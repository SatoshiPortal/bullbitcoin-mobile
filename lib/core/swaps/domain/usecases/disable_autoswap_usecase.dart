import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';

class DisableAutoswapUsecase {
  final BoltzSwapRepository _mainnetRepository;
  final BoltzSwapRepository _testnetRepository;

  DisableAutoswapUsecase({
    required BoltzSwapRepository mainnetRepository,
    required BoltzSwapRepository testnetRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository;

  Future<AutoSwap> execute({required bool isTestnet}) async {
    final repository = isTestnet ? _testnetRepository : _mainnetRepository;
    final currentSettings = await repository.getAutoSwapParams();
    final disabledSettings = currentSettings.copyWith(enabled: false);
    await repository.updateAutoSwapParams(disabledSettings);
    return disabledSettings;
  }
}
