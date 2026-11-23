import 'dart:async';

import 'swap_watcher.dart';
import 'usecases/log_swap_census_usecase.dart';

/// Logs a census of every stored swap, then starts the swap watcher: the only
/// driver that claims, refunds and coop-signs ongoing swaps. It runs once the
/// keychain is readable, since resolving a swap reads its secrets. The watcher
/// never throws and is not awaited, so it cannot delay startup.
class SwapStartup {
  final LogSwapCensusUsecase _logSwapCensusUsecase;
  final SwapWatcher _swapWatcher;

  const SwapStartup(this._logSwapCensusUsecase, this._swapWatcher);

  Future<void> execute() async {
    await _logSwapCensusUsecase.execute();
    unawaited(_swapWatcher.start());
  }
}
