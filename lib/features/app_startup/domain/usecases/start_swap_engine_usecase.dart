import 'dart:async';

import 'package:bb_mobile/core/swaps/swap_engine_switcher.dart';
import 'package:swaps/swaps.dart';

/// Logs a census of every stored swap, then starts the swap watcher: the only
/// driver that claims, refunds and coop-signs ongoing swaps, and the switcher
/// that moves it to the other network when the user switches. The watcher
/// never throws and is not awaited, so it cannot delay startup.
class StartSwapEngineUsecase {
  final LogSwapCensusUsecase _logSwapCensusUsecase;
  final SwapWatcher _swapWatcher;
  final SwapEngineSwitcher _swapEngineSwitcher;

  const StartSwapEngineUsecase(
    this._logSwapCensusUsecase,
    this._swapWatcher,
    this._swapEngineSwitcher,
  );

  Future<void> execute() async {
    await _logSwapCensusUsecase.execute();
    _swapEngineSwitcher.start();
    unawaited(_swapWatcher.start());
  }
}
