class AutosweepFeePolicy {
  static const defaultBitcoinMaxFeePercent = 3.0;

  final double bitcoinMaxFeePercent;

  const AutosweepFeePolicy({
    this.bitcoinMaxFeePercent = defaultBitcoinMaxFeePercent,
  });

  bool allowsBitcoinSweep({
    required int feeSat,
    required BigInt walletBalanceSat,
  }) {
    if (walletBalanceSat <= BigInt.zero) return false;
    final feePercent = (feeSat / walletBalanceSat.toDouble()) * 100;
    return feePercent <= bitcoinMaxFeePercent;
  }
}
