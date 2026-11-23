import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart'
    show SwapRouteSettings, SwapRouting, SwapsFailure;
import 'package:meta/meta.dart';

class GetSwapRouteSettingsUsecase {
  final SwapRouting _routing;

  const GetSwapRouteSettingsUsecase(this._routing);

  @useResult
  Future<Result<SwapRouteSettings, SwapsFailure>> execute() =>
      _routing.readRouteSettings();
}
