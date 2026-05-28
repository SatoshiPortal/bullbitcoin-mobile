import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// The slow preset is pinned to the network minrelayfee (0.1 sat/vByte)
/// instead of mempool's `minimumFee`. Regression-locks the policy after
/// #2133 — replacing this with `minimumFee` from the API again would
/// silently make Slow indistinguishable from Economic at quiet blocks.
void main() {
  group('BitcoinFeePresetPolicy.fromMempool', () {
    test('slow is pinned to the network minrelayfee (0.1 sat/vByte)', () {
      final opts = BitcoinFeePresetPolicy.fromMempool(
        fastestSatPerVbyte: 25,
        economicSatPerVbyte: 5,
      );
      final slow = opts.slow as RelativeFee;
      expect(slow.satPerVbyte, NetworkFeeRelayPolicy.minRelaySatPerVbyte);
      expect(slow.satPerKwu, NetworkFeeRelayPolicy.minRelaySatPerKwu);
    });

    test('fastest and economic pass through verbatim', () {
      final opts = BitcoinFeePresetPolicy.fromMempool(
        fastestSatPerVbyte: 25,
        economicSatPerVbyte: 5,
      );
      expect((opts.fastest as RelativeFee).satPerVbyte, 25);
      expect((opts.economic as RelativeFee).satPerVbyte, 5);
    });

    test('slow stays at 0.1 even when mempool minimumFee would be 1', () {
      // Caller intentionally doesn't pass minimumFee — but if they ever
      // did, the policy ignores it. The pin is unconditional.
      final opts = BitcoinFeePresetPolicy.fromMempool(
        fastestSatPerVbyte: 2,
        economicSatPerVbyte: 1,
      );
      expect((opts.slow as RelativeFee).satPerVbyte, 0.1);
    });
  });
}
