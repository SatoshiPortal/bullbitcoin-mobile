import 'dart:async';

import 'package:bb_mobile/core/swaps/data/services/auto_swap_timer_service.dart';

class ListenToAutoSwapTimerUsecase {
  final AutoSwapTimerService _mainnetAutoSwapTimer;
  final AutoSwapTimerService _testnetAutoSwapTimer;

  ListenToAutoSwapTimerUsecase({
    required AutoSwapTimerService mainnetAutoSwapTimer,
    required AutoSwapTimerService testnetAutoSwapTimer,
  }) : _mainnetAutoSwapTimer = mainnetAutoSwapTimer,
       _testnetAutoSwapTimer = testnetAutoSwapTimer;

  Stream<AutoSwapEvent> execute({required bool isTestnet}) {
    final timerService =
        isTestnet ? _testnetAutoSwapTimer : _mainnetAutoSwapTimer;
    timerService.startTimer();
    return timerService.autoSwapEvents;
  }
}
