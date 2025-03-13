import 'dart:async';

import 'package:bb_mobile/_core/domain/entities/swap.dart';

abstract class SwapWatcherService {
  void startWatching();
  Future<void> restartWatcherWithOngoingSwaps();
  StreamSubscription<Swap>? get swapSubscription;
}
