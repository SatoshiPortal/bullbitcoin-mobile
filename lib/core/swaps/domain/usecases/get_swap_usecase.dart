import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

class GetSwapUsecase {
  // This class is responsible for fetching swap data
  // from the repository and returning it to the presenter.
  final BoltzSwapRepository _mainnetBoltzSwapRepository;
  final BoltzSwapRepository _testnetBoltzSwapRepository;
  final SettingsRepository _settingsRepository;

  GetSwapUsecase({
    required BoltzSwapRepository mainnetBoltzSwapRepository,
    required BoltzSwapRepository testnetBoltzSwapRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetBoltzSwapRepository = mainnetBoltzSwapRepository,
       _testnetBoltzSwapRepository = testnetBoltzSwapRepository,
       _settingsRepository = settingsRepository;

  Future<Swap> execute(String swapId) async {
    try {
      // Fetch settings to determine environment for swap repository
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final swap =
          isTestnet
              ? await _testnetBoltzSwapRepository.getSwap(swapId: swapId)
              : await _mainnetBoltzSwapRepository.getSwap(swapId: swapId);

      return swap;
    } catch (e) {
      throw GetSwapException('$e');
    }
  }
}

class GetSwapException implements Exception {
  final String message;

  GetSwapException(this.message);
}
