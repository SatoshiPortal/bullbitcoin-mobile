import 'dart:math';

import 'package:bb_mobile/core/fees/data/models/mempool_fees_model.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';

/// Maps a mempool fees response into the app's three preset tiers.
///
/// Tier policy:
/// - **Fastest**  ← `fastestFee` (next-block target).
/// - **Economic** ← `hourFee` (~1-hour target).
/// - **Slow**     ← `economyFee`.
///
/// Every tier is floored at the network minrelayfee so no preset can drop
/// below what the network will relay. Because mempool returns the fields in
/// non-increasing order (`fastestFee ≥ hourFee ≥ economyFee`) and `max` is
/// monotonic, flooring all three preserves the Fastest ≥ Economic ≥ Slow
/// ordering even in the pathological case where a server reports rates below
/// the floor (which would otherwise invert Slow above Economic).
///
/// `halfHourFee` and `minimumFee` are intentionally unused — the app exposes
/// exactly three tiers, and Slow is floor-protected rather than tracking
/// mempool's `minimumFee` (which collapses to ~1 sat/vByte at quiet blocks
/// and would make Slow indistinguishable from a real economy rate).
class MempoolFeesMapper {
  const MempoolFeesMapper._();

  static FeeOptions toFeeOptions(MempoolFeesModel model) {
    RelativeFee tier(double satPerVbyte) => NetworkFee.relativeFromSatPerVbyte(
      max(satPerVbyte, NetworkFeeRelayPolicy.minRelaySatPerVbyte),
    );
    return FeeOptions(
      fastest: tier(model.fastestFee),
      economic: tier(model.hourFee),
      slow: tier(model.economyFee),
    );
  }
}
