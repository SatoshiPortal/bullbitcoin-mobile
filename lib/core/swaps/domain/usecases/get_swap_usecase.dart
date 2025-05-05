import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';

class GetSwapUsecase {
  // This class is responsible for fetching swap data
  // from the repository and returning it to the presenter.
  final SwapRepository _mainnetSwapRepository;
  final SwapRepository _testnetSwapRepository;

  GetSwapUsecase({
    required SwapRepository mainnetSwapRepository,
    required SwapRepository testnetSwapRepository,
  }) : _mainnetSwapRepository = mainnetSwapRepository,
       _testnetSwapRepository = testnetSwapRepository;

  Future<Swap> execute(String swapId, {required bool isTestnet}) async {
    try {
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
