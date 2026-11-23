import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart'
    show SwapRouteOverride, SwapRouting, SwapsFailure;
import 'package:meta/meta.dart';

class SetSwapRouteOverrideUsecase {
  final SwapRouting _routing;

  const SetSwapRouteOverrideUsecase(this._routing);

  @useResult
  Future<Result<void, SwapsFailure>> execute(SwapRouteOverride override) =>
      _routing.setRouteOverride(override);
}
