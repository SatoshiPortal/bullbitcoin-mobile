import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';

class GetSwapsUsecase {
  final SwapRepository _mainnetSwapRepository;
  final SwapRepository _testnetSwapRepository;
  final SettingsRepository _settingsRepository;

  GetSwapsUsecase({
    required SwapRepository mainnetSwapRepository,
    required SwapRepository testnetSwapRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetSwapRepository = mainnetSwapRepository,
       _testnetSwapRepository = testnetSwapRepository,
       _settingsRepository = settingsRepository;

  Future<List<Swap>> execute({String? walletId}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;

      final swaps =
          isTestnet
              ? await _testnetSwapRepository.getAllSwaps(
                walletId: walletId,
                isTestnet: true,
              )
              : await _mainnetSwapRepository.getAllSwaps(
                walletId: walletId,
                isTestnet: false,
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
