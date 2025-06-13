import 'dart:async';

import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

abstract class SwapWatcherService {
  Future<void> restartWatcherWithOngoingSwaps();
  Future<void> processSwap(Swap swap);
  Stream<Swap> get swapStream;
}
