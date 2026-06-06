enum BackgroundTask {
  bitcoinSync('bitcoin-sync', 'com.bullbitcoin.mobile.bitcoin-sync-id'),
  liquidSync('liquid-sync', 'com.bullbitcoin.mobile.liquid-sync-id'),
  swapsSync('swaps-sync', 'com.bullbitcoin.mobile.swaps-sync-id'),
  logsPrune('logs-prune', 'com.bullbitcoin.mobile.logs-prune-id');

  final String name;
  final String id;
  const BackgroundTask(this.name, this.id);

  /// Resolves a task by EITHER its short name OR its iOS BGTaskScheduler
  /// identifier. The two forms reach `executeTask` depending on platform:
  ///
  /// - **Android** (`workmanager_android`): forwards `request.taskName`
  ///   (the second arg of `Workmanager().registerPeriodicTask(uniqueName,
  ///   taskName)`), so we receive the short name like `"logs-prune"`.
  /// - **iOS** (`workmanager_apple`): forwards the BGTaskScheduler
  ///   identifier registered in `AppDelegate.swift`, so we receive
  ///   `"com.bullbitcoin.mobile.logs-prune-id"`.
  ///
  /// The asymmetry is undocumented in the workmanager README but
  /// confirmed by reading `workmanager_apple/BackgroundWorker.swift`
  /// (passes `identifier` to Dart) vs `workmanager_android` (passes
  /// `taskName`). Several open issues track confusion around it
  /// (#396, #450, #524). Accepting either form makes the dispatch
  /// platform-agnostic without per-platform glue at the call site.
  static BackgroundTask fromName(String name) {
    for (final task in BackgroundTask.values) {
      if (task.name == name || task.id == name) return task;
    }
    throw Exception('Unknown Background Task: $name');
  }
}
