abstract interface class BitcoinChainTipPort {
  Future<({int height, int medianTimePast})> getChainTip({
    required bool isTestnet,
  });
}
