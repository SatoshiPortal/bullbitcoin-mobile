import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class GetSwapLimitsUsecase {
  final BoltzSwapRepository _mainnetBoltzSwapRepository;
  final BoltzSwapRepository _testnetBoltzSwapRepository;

  GetSwapLimitsUsecase({
    required BoltzSwapRepository mainnetBoltzSwapRepository,
    required BoltzSwapRepository testnetBoltzSwapRepository,
  }) : _mainnetBoltzSwapRepository = mainnetBoltzSwapRepository,
       _testnetBoltzSwapRepository = testnetBoltzSwapRepository;

  Future<(SwapLimits, SwapFees)> execute({
    required SwapType type,
    bool isTestnet = false,
    bool updateLimitsAndFees = true,
  }) async {
    try {
      final swapRepository =
          isTestnet ? _testnetBoltzSwapRepository : _mainnetBoltzSwapRepository;
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
