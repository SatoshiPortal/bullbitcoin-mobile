import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

class GetSwapLimitsUsecase {
  const GetSwapLimitsUsecase();

  Future<(SwapLimits, SwapFees)> execute({
    required SwapType type,
    bool updateLimitsAndFees = true,
  }) async => throw GetSwapLimitsException('legacy_swap_provider_disabled');
}

class GetSwapLimitsException extends BullException {
  GetSwapLimitsException(super.message);
}
