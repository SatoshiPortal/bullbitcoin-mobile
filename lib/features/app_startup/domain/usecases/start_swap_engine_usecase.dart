import 'dart:async';

import 'package:swaps/swaps.dart';

/// Logs a census of every stored swap, then starts the swap watcher: the only
/// driver that claims, refunds and coop-signs ongoing swaps. It runs once the
/// keychain is readable, since resolving a swap reads its secrets. The watcher
/// never throws and is not awaited, so it cannot delay startup.
class StartSwapEngineUsecase {
  final LogSwapCensusUsecase _logSwapCensusUsecase;
  final SwapWatcher _swapWatcher;

  const StartSwapEngineUsecase(this._logSwapCensusUsecase, this._swapWatcher);

  Future<void> execute() async {
    await _logSwapCensusUsecase.execute();
    unawaited(_swapWatcher.start());
  }
}
