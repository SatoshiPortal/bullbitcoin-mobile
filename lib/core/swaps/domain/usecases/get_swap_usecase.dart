import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';

class GetSwapUsecase {
  // This class is responsible for fetching swap data
  // from the repository and returning it to the presenter.
  final SwapRepository _mainnetSwapRepository;
  final SwapRepository _testnetSwapRepository;
  final SettingsRepository _settingsRepository;

  GetSwapUsecase({
    required SwapRepository mainnetSwapRepository,
    required SwapRepository testnetSwapRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetSwapRepository = mainnetSwapRepository,
       _testnetSwapRepository = testnetSwapRepository,
       _settingsRepository = settingsRepository;

  Future<Swap> execute(String swapId) async {
    try {
      // Fetch settings to determine environment for swap repository
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final swap =
          isTestnet
              ? await _testnetSwapRepository.getSwap(swapId: swapId)
              : await _mainnetSwapRepository.getSwap(swapId: swapId);

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
