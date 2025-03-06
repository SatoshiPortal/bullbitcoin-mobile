abstract class SwapWatcherService {
  void startWatching();
  Future<void> restartWatcherWithOngoingSwaps();
}
