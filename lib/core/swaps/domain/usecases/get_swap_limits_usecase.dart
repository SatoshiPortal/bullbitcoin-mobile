import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class GetSwapLimitsUsecase {
  final SwapRepository _mainnetSwapRepository;
  final SwapRepository _testnetSwapRepository;

  GetSwapLimitsUsecase({
    required SwapRepository mainnetSwapRepository,
    required SwapRepository testnetSwapRepository,
  }) : _mainnetSwapRepository = mainnetSwapRepository,
       _testnetSwapRepository = testnetSwapRepository;

  Future<(SwapLimits, SwapFees)> execute({
    required SwapType type,
    bool isTestnet = false,
    bool updateLimitsAndFees = true,
  }) async {
    try {
      final swapRepository =
          isTestnet ? _testnetSwapRepository : _mainnetSwapRepository;
      if (updateLimitsAndFees) {
        await swapRepository.updateSwapLimitsAndFees(type);
      }
      final result = await swapRepository.getSwapLimitsAndFees(type);
      return result;
    } catch (e) {
      log.severe('[GetSwapLimitsUsecase] Error getting swap limits: $e');
      throw GetSwapLimitsException(e.toString());
    }
  }
}

class GetSwapLimitsException implements Exception {
  final String message;

  GetSwapLimitsException(this.message);

  @override
  String toString() => 'GetSwapLimitsException: $message';
}
