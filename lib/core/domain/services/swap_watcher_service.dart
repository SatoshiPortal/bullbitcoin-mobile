import 'dart:async';

import 'package:bb_mobile/core/domain/entities/swap.dart';

abstract class SwapWatcherService {
  Future<void> restartWatcherWithOngoingSwaps();
  Stream<Swap> get swapStream;
}
