import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

class GetSwapsUsecase {
  final BoltzSwapRepository _mainnetBoltzSwapRepository;
  final BoltzSwapRepository _testnetBoltzSwapRepository;
  final SettingsRepository _settingsRepository;

  GetSwapsUsecase({
    required BoltzSwapRepository mainnetBoltzSwapRepository,
    required BoltzSwapRepository testnetBoltzSwapRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetBoltzSwapRepository = mainnetBoltzSwapRepository,
       _testnetBoltzSwapRepository = testnetBoltzSwapRepository,
       _settingsRepository = settingsRepository;

  Future<List<Swap>> execute({String? walletId}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;

      final swaps =
          isTestnet
              ? await _testnetBoltzSwapRepository.getAllSwaps(
                walletId: walletId,
              )
              : await _mainnetBoltzSwapRepository.getAllSwaps(
                walletId: walletId,
              );
      return swaps;
    } catch (e) {
      throw GetSwapsException('Failed to fetch swaps: $e');
    }
  }
}

class GetSwapsException implements Exception {
  final String message;

  GetSwapsException(this.message);

  @override
  String toString() => '[GetSwapsUsecase]: $message';
}
