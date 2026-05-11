import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class GetSwapLimitsUsecase {
  final BoltzSwapRepository _boltzSwapRepository;

  GetSwapLimitsUsecase({required BoltzSwapRepository boltzSwapRepository})
    : _boltzSwapRepository = boltzSwapRepository;

  Future<(SwapLimits, SwapFees)> execute({
    required SwapType type,
    bool updateLimitsAndFees = true,
  }) async {
    try {
      if (updateLimitsAndFees) {
        await _boltzSwapRepository.updateSwapLimitsAndFees(type);
      }
      return await _boltzSwapRepository.getSwapLimitsAndFees(type);
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
