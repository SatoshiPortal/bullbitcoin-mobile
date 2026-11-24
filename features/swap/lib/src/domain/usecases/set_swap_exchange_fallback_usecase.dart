import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart' show SwapRouting, SwapsFailure;
import 'package:meta/meta.dart';

class SetSwapExchangeFallbackUsecase {
  final SwapRouting _routing;

  const SetSwapExchangeFallbackUsecase(this._routing);

  @useResult
  Future<Result<void, SwapsFailure>> execute(bool enabled) =>
      _routing.setExchangeFallbackEnabled(enabled);
}
