import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';

class DisableAutoswapWarningUsecase {
  final BoltzSwapRepository _mainnetRepository;
  final BoltzSwapRepository _testnetRepository;

  DisableAutoswapWarningUsecase({
    required BoltzSwapRepository mainnetRepository,
    required BoltzSwapRepository testnetRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository;

  Future<AutoSwap> execute({required bool isTestnet}) async {
    final repository = isTestnet ? _testnetRepository : _mainnetRepository;
    final currentSettings = await repository.getAutoSwapParams();
    final updatedSettings = currentSettings.copyWith(showWarning: false);
    await repository.updateAutoSwapParams(updatedSettings);
    return updatedSettings;
  }
}
