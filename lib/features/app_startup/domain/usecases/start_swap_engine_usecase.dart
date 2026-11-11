import 'dart:async';

import 'package:boltz_swaps/boltz_swaps.dart';

/// Logs a census of every stored swap, then starts the swap watcher: the only
/// driver that claims, refunds and coop-signs ongoing swaps. The watcher never
/// throws and is not awaited, so it cannot delay startup.
class StartSwapEngineUsecase {
  final LogSwapCensusUsecase _logSwapCensusUsecase;
  final SwapWatcher _swapWatcher;

  const StartSwapEngineUsecase(this._logSwapCensusUsecase, this._swapWatcher);

  Future<void> execute() async {
    await _logSwapCensusUsecase.execute();
    unawaited(_swapWatcher.start());
  }
}
