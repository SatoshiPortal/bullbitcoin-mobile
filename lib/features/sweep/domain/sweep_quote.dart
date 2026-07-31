import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_plan.dart';

/// A built, unsigned sweep and the numbers read back off it.
///
/// [feeSat] is the real fee the SDK put in the PSBT, not a rate multiplied by
/// an estimated size — so what the review screen shows is what gets paid.
final class SweepQuote {
  final SweepPlan plan;
  final NetworkFee networkFee;
  final String unsignedPsbt;
  final int txSize;
  final BigInt feeSat;

  const SweepQuote({
    required this.plan,
    required this.networkFee,
    required this.unsignedPsbt,
    required this.txSize,
    required this.feeSat,
  });

  /// What returns to the spending wallet's own change output, or `null` when a
  /// recipient absorbs the remainder instead.
  BigInt? get changeSat => plan.changeSat(feeSat);

  /// What the remainder recipient receives, or `null` when there is none.
  BigInt? get remainderSat => plan.remainderSat(feeSat);

  /// True when the leftover was too small to be worth an output and the SDK
  /// folded it into the fee instead. Worth telling the user: they pay a higher
  /// fee than the chosen rate implies, and no change comes back.
  bool get changeAbsorbedIntoFee {
    final change = changeSat;
    return change != null && change <= BigInt.zero;
  }

  /// Review rate in sat/vByte. Relative fees retain BDK's exact requested rate;
  /// absolute fees are expressed against the available unsigned size.
  double get satPerVbyte => switch (networkFee) {
    RelativeFee(:final satPerKwu) => satPerKwu / 250.0,
    AbsoluteFee() => txSize > 0 ? feeSat.toInt() / txSize : 0,
  };

  /// Total leaving the wallet — what the recipients receive plus the fee, with
  /// any change that comes back excluded.
  BigInt get totalSpentSat {
    final change = changeSat;
    if (change == null || change <= BigInt.zero) return plan.totalInputSat;
    return plan.totalInputSat - change;
  }
}
