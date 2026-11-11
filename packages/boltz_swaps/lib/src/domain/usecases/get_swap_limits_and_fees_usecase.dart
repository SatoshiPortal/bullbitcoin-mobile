import 'package:boltz_swaps/src/domain/entities/swap.dart';
import 'package:boltz_swaps/src/domain/entities/swap_failure.dart';
import 'package:boltz_swaps/src/domain/swap_repository.dart';
import 'package:boltz_swaps/src/log.dart';
import 'package:primitives/primitives.dart';

class GetSwapLimitsAndFeesUsecase {
  GetSwapLimitsAndFeesUsecase({required this._swapRepository});

  final SwapRepository _swapRepository;

  Future<Result<(SwapLimits, SwapFees), SwapsFailure>> execute(
    SwapType type,
  ) async {
    try {
      return Ok(await _swapRepository.limitsAndFees(type));
    } catch (e) {
      final failure = classifySwapCreationFailure(e);
      swapsLog.warning('SWAPS: limits for ${type.name} unavailable: $failure');
      return Err(failure);
    }
  }
}
