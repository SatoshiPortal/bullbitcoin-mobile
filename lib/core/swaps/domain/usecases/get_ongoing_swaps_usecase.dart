import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

class GetOngoingSwapsUsecase {
  GetOngoingSwapsUsecase({
    required BoltzSwapRepository mainnetBoltzSwapRepository,
    required BoltzSwapRepository testnetBoltzSwapRepository,
    required SettingsRepository settingsRepository,
  })  : _mainnetBoltzSwapRepository = mainnetBoltzSwapRepository,
        _testnetBoltzSwapRepository = testnetBoltzSwapRepository,
        _settingsRepository = settingsRepository;

  final BoltzSwapRepository _mainnetBoltzSwapRepository;
  final BoltzSwapRepository _testnetBoltzSwapRepository;
  final SettingsRepository _settingsRepository;

  Future<List<Swap>> execute({String? walletId}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;

      return isTestnet
          ? await _testnetBoltzSwapRepository.getOngoingSwaps(
              walletId: walletId,
            )
          : await _mainnetBoltzSwapRepository.getOngoingSwaps(
              walletId: walletId,
            );
    } catch (e) {
      throw GetOngoingSwapsException('Failed to fetch ongoing swaps: $e');
    }
  }
}

class GetOngoingSwapsException extends BullException {
  GetOngoingSwapsException(super.message);
}
