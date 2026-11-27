import 'package:swaps/swaps.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';

/// Whether the swap server answers with the address and credentials in the
/// swap settings.
class CheckSwapServerUsecase {
  final BoltzSwaps _boltz;

  CheckSwapServerUsecase({required this._boltz});

  Future<bool> execute() async {
    switch (await _boltz.checkServer()) {
      case Ok():
        return true;
      case Err(:final failure):
        log.warning('Swap server unreachable (${failure.runtimeType})');
        return false;
    }
  }
}
