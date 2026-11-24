import 'package:primitives/primitives.dart' show Sats;

final class LnurlPayLimits {
  final int minimumSat;
  final int maximumSat;

  const LnurlPayLimits._(this.minimumSat, this.maximumSat);

  static LnurlPayLimits? fromMillisatoshis(BigInt min, BigInt max) {
    if (min <= BigInt.zero || max < min) return null;
    final millisatsPerSat = BigInt.from(1000);
    final minimum = (min + millisatsPerSat - BigInt.one) ~/ millisatsPerSat;
    final maximum = max ~/ millisatsPerSat;
    final payableMax = maximum > Sats.maxBitcoinSupply
        ? Sats.maxBitcoinSupply
        : maximum;
    return minimum <= payableMax
        ? LnurlPayLimits._(minimum.toInt(), payableMax.toInt())
        : null;
  }

  int? get fixedAmountSat => minimumSat == maximumSat ? minimumSat : null;

  bool includes(int sats) => sats >= minimumSat && sats <= maximumSat;
}
