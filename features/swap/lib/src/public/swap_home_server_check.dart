import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart' show BoltzSwaps;

import '../domain/usecases/check_swap_server_usecase.dart';

/// Safe server reachability for the Home warning, without returning details
/// about configured credentials or the transport failure.
abstract interface class SwapHomeServerCheck {
  factory SwapHomeServerCheck(BoltzSwaps boltz) = _SwapHomeServerCheck;

  Future<bool> reachable();
}

final class _SwapHomeServerCheck implements SwapHomeServerCheck {
  final CheckSwapServerUsecase _check;

  _SwapHomeServerCheck(BoltzSwaps boltz)
    : _check = CheckSwapServerUsecase(boltz);

  @override
  Future<bool> reachable() async {
    switch (await _check.execute()) {
      case Ok():
        return true;
      case Err(:final failure):
        log.warning('Swap server unreachable (${failure.runtimeType})');
        return false;
    }
  }
}
