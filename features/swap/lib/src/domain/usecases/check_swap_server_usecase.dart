import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart' show BoltzSwaps, SwapsFailure;

class CheckSwapServerUsecase {
  final BoltzSwaps _boltz;

  const CheckSwapServerUsecase(this._boltz);

  @useResult
  Future<Result<void, SwapsFailure>> execute() => _boltz.checkServer();
}
