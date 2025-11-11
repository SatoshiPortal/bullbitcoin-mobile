enum BackgroundTask {
  bitcoinSync('com.bullbitcoin.app.bitcoinSync'),
  liquidSync('com.bullbitcoin.app.liquidSync'),
  swapsSync('com.bullbitcoin.app.swapsSync'),
  logsPrune('com.bullbitcoin.app.logsPrune'),
  servicesCheck('com.bullbitcoin.app.servicesCheck');

  final String name;
  const BackgroundTask(this.name);

  static BackgroundTask fromName(String name) {
    return BackgroundTask.values.firstWhere(
      (e) => e.name == name,
      orElse: () => throw Exception('Unknown Task name: $name'),
    );
  }
}
