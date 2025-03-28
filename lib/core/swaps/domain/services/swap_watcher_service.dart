import 'dart:async';

import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';


abstract class SwapWatcherService {
  Future<void> restartWatcherWithOngoingSwaps();
  Stream<Swap> get swapStream;
}
