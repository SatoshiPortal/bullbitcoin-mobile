abstract class SwapWatcherService {
  Future<void> startWatching();
  Future<void> restartWatcherWithOngoingSwaps();
}
