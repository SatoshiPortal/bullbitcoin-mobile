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
/// The relay floor is `max(minimumFee, 0.1 sat/vByte)`: the live mempool
/// `minimumFee` (the rate below which that node won't relay — typically 0.1
/// at quiet blocks, higher under congestion), clamped up to the static 0.1
/// safety floor. Every tier is floored at it, and it is exposed as
/// [FeeOptions.minRelay] so the validation gates reject anything below the
/// network's current minimum rather than a hardcoded constant. Because
/// mempool returns the fields in non-increasing order (`fastestFee ≥ hourFee
/// ≥ economyFee ≥ minimumFee`) and `max` is monotonic, flooring all three
/// preserves the Fastest ≥ Economic ≥ Slow ordering.
///
/// `halfHourFee` is intentionally unused — the app exposes exactly three
/// tiers. `minimumFee` feeds only the relay floor (above), never a tier, so
/// Slow stays a real economy rate instead of collapsing onto the floor.
class MempoolFeesMapper {
  const MempoolFeesMapper._();

  static FeeOptions toFeeOptions(MempoolFeesModel model) {
    final floorSatPerVbyte = max(
      model.minimumFee,
      NetworkFeeRelayPolicy.minRelaySatPerVbyte,
    );
    RelativeFee tier(double satPerVbyte) =>
        NetworkFee.relativeFromSatPerVbyte(max(satPerVbyte, floorSatPerVbyte));
    return FeeOptions(
      fastest: tier(model.fastestFee),
      economic: tier(model.hourFee),
      slow: tier(model.economyFee),
      minRelay: NetworkFee.relativeFromSatPerVbyte(floorSatPerVbyte),
    );
  }
}
