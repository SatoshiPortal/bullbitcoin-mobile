import 'package:bb_mobile/core/errors/bull_exception.dart';
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
      final swapRepository = isTestnet
          ? _testnetBoltzSwapRepository
          : _mainnetBoltzSwapRepository;
      if (updateLimitsAndFees) {
        await swapRepository.updateSwapLimitsAndFees(type);
      }
      final result = await swapRepository.getSwapLimitsAndFees(type);
      return result;
    } catch (e) {
      log.severe(
        message: 'Error getting swap limits',
        error: e,
        trace: StackTrace.current,
      );
      throw GetSwapLimitsException(e.toString());
    }
  }
}

class GetSwapLimitsException extends BullException {
  GetSwapLimitsException(super.message);
}
