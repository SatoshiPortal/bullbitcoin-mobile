enum BackgroundTask {
  bitcoinSync('bitcoin-sync', 'com.bullbitcoin.mobile.bitcoin-sync-id'),
  liquidSync('liquid-sync', 'com.bullbitcoin.mobile.liquid-sync-id'),
  swapsSync('swaps-sync', 'com.bullbitcoin.mobile.swaps-sync-id'),
  logsPrune('logs-prune', 'com.bullbitcoin.mobile.logs-prune-id');

  final String name;
  final String id;
  const BackgroundTask(this.name, this.id);

  static BackgroundTask fromName(String name) {
    switch (name) {
      case 'bitcoin-sync':
        return BackgroundTask.bitcoinSync;
      case 'liquid-sync':
        return BackgroundTask.liquidSync;
      case 'swaps-sync':
        return BackgroundTask.swapsSync;
      case 'logs-prune':
        return BackgroundTask.logsPrune;
      default:
        throw Exception('Unknown Background Task: $name');
    }
  }
}
