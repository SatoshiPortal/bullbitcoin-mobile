import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_payjoin/src/engine/payjoin_fee_cap.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

final class _FeesPort implements PayjoinFeesPort {
  final double? satsPerVbyte;

  const _FeesPort(this.satsPerVbyte);

  const _FeesPort.failing() : satsPerVbyte = null;

  @override
  Future<FeeRate> fastestFeeRate({required BitcoinNetwork network}) async {
    final rate = satsPerVbyte;
    if (rate == null) throw Exception('mempool unreachable');
    return FeeRate(rate);
  }
}

Future<int> _cap(_FeesPort fees) =>
    receiverMaxFeeRateSatPerVb(fees, BitcoinNetwork.mainnet);

void main() {
  group('receiver fee cap', () {
    test('tracks the live fastest rate times the multiplier', () async {
      expect(await _cap(const _FeesPort(10)), 30);
    });

    test('never drops below the floor on a quiet mempool', () async {
      expect(
        await _cap(const _FeesPort(1)),
        PayjoinConstants.minMaxFeeRateSatPerVb,
      );
    });

    test('is clamped to the ceiling when the fee source reports an absurd '
        'rate', () async {
      // The mempool server is user-configurable, so a wild value must not
      // widen the cap — at the ceiling the worst case is ~10,000 sats burned
      // instead of ~1,000,000.
      expect(
        await _cap(const _FeesPort(100000)),
        PayjoinConstants.maxMaxFeeRateSatPerVb,
      );
    });

    test('falls back to the floor when the fee lookup fails', () async {
      expect(
        await _cap(const _FeesPort.failing()),
        PayjoinConstants.minMaxFeeRateSatPerVb,
      );
    });

    test('is never the old hardcoded 10000 sat/vB', () async {
      // Regression guard for the burn this cap exists to bound: a sender's
      // minfeerate is attacker-controlled, so maxEffectiveFeeRate was the only
      // bound, and 10000 sat/vB let a ~100 vB contribution cost the receiver
      // ~1,000,000 sats of its own change.
      for (final rate in [0.5, 1.0, 10.0, 500.0, 100000.0]) {
        expect(await _cap(_FeesPort(rate)), lessThan(10000));
      }
    });
  });
}
