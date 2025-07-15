import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';

class SaveAutoSwapSettingsUsecase {
  final SwapRepository _mainnetRepository;
  final SwapRepository _testnetRepository;

  SaveAutoSwapSettingsUsecase({
    required SwapRepository mainnetRepository,
    required SwapRepository testnetRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository;

  Future<void> execute(AutoSwap params, {required bool isTestnet}) async {
    final repository = isTestnet ? _testnetRepository : _mainnetRepository;
    await repository.updateAutoSwapParams(params);
  }
}
