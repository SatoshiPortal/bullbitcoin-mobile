import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/boltz_swaps.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';

class GetSwapLimitsAndFeesUsecase {
  final BoltzSwaps _boltz;

  const GetSwapLimitsAndFeesUsecase(this._boltz);

  Future<Result<(SwapLimits, SwapFees), SwapsFailure>> execute(SwapType type) =>
      _boltz.limitsAndFees(type);
}
