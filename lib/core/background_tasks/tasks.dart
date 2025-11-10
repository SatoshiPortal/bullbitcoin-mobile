enum BackgroundTask {
  bitcoinSync('bitcoin-sync'),
  liquidSync('liquid-sync'),
  swapsSync('swaps-sync'),
  logsPrune('logs-prune'),
  servicesCheck('services-check');

  final String name;
  const BackgroundTask(this.name);

  static BackgroundTask fromName(String name) {
    return BackgroundTask.values.firstWhere(
      (e) => e.name == name,
      orElse: () => throw Exception('Unknown Task name: $name'),
    );
  }
}
