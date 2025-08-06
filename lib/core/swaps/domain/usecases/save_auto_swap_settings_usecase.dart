import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';

class SaveAutoSwapSettingsUsecase {
  final BoltzSwapRepository _mainnetRepository;
  final BoltzSwapRepository _testnetRepository;

  SaveAutoSwapSettingsUsecase({
    required BoltzSwapRepository mainnetRepository,
    required BoltzSwapRepository testnetRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository;

  Future<void> execute(AutoSwap params, {required bool isTestnet}) async {
    final repository = isTestnet ? _testnetRepository : _mainnetRepository;
    await repository.updateAutoSwapParams(params);
  }
}
