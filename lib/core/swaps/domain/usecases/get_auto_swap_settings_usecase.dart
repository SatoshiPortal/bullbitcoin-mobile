import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';

class GetAutoSwapSettingsUsecase {
  final SwapRepository _mainnetRepository;
  final SwapRepository _testnetRepository;

  GetAutoSwapSettingsUsecase({
    required SwapRepository mainnetRepository,
    required SwapRepository testnetRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository;

  Future<AutoSwap> execute({required bool isTestnet}) async {
    final repository = isTestnet ? _testnetRepository : _mainnetRepository;
    return await repository.getAutoSwapParams();
  }
}
