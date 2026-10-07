enum BackgroundTask {
  bitcoinSync('bitcoin-sync', 'com.bullbitcoin.mobile.bitcoin-sync-id'),
  liquidSync('liquid-sync', 'com.bullbitcoin.mobile.liquid-sync-id'),
  swapsSync('swaps-sync', 'com.bullbitcoin.mobile.swaps-sync-id'),
  logsPrune('logs-prune', 'com.bullbitcoin.mobile.logs-prune-id');

  final String name;
  final String id;
  const BackgroundTask(this.name, this.id);

  static BackgroundTask? resolve(String value) {
    for (final task in values) {
      if (task.name == value || task.id == value) return task;
    }
    return null;
  }
}
