enum FeeRateType { fastest, fast, medium, slow, custom }

class FeeRate {
  FeeRate({
    required this.fastest,
    required this.fast,
    required this.medium,
    required this.slow,
  });

  final int fastest;
  final int fast;
  final int medium;
  final int slow;

  factory FeeRate.createDefaultFeeRate() {
    return FeeRate(
      fastest: 0,
      fast: 0,
      medium: 0,
      slow: 0,
    );
  }

  int getFeeValue(FeeRateType feeRate) {
    switch(feeRate) {
      case FeeRateType.fastest:
        return fastest;
      case FeeRateType.fast:
        return fast;
      case FeeRateType.medium:
        return medium;
      case FeeRateType.slow:
        return slow;
      default:
        return 0;
    }
  }
}