import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks in the single source of truth for the network minrelayfee floor.
/// Previously the `0.1 sat/vByte` literal was duplicated in send_cubit,
/// transfer_bloc, and custom_fee_list_item — all three now call
/// `fee.aboveMinRelay(...)`.
void main() {
  group('NetworkFeeRelayPolicy.minRelay constants', () {
    test('0.1 sat/vByte equals 25 sat/kwu (exact)', () {
      expect(NetworkFeeRelayPolicy.minRelaySatPerVbyte, 0.1);
      expect(NetworkFeeRelayPolicy.minRelaySatPerKwu, 25);
      // 0.1 sat/vByte × 250 = 25 sat/kwu; this is the unit the SDK
      // boundary expects.
      expect(
        NetworkFeeRelayPolicy.minRelaySatPerKwu,
        (NetworkFeeRelayPolicy.minRelaySatPerVbyte * 250).round(),
      );
    });
  });

  group('NetworkFee.aboveMinRelay — RelativeFee', () {
    test('exactly at the floor (25 sat/kwu) passes', () {
      const fee = RelativeFee(25);
      expect(fee.aboveMinRelay(), isTrue);
    });

    test('one tick below the floor (24 sat/kwu) fails', () {
      const fee = RelativeFee(24);
      expect(fee.aboveMinRelay(), isFalse);
    });

    test('well above the floor (1 sat/vB → 250 sat/kwu) passes', () {
      const fee = RelativeFee(250);
      expect(fee.aboveMinRelay(), isTrue);
    });

    test('zero rate fails', () {
      const fee = RelativeFee(0);
      expect(fee.aboveMinRelay(), isFalse);
    });
  });

  group('NetworkFee.aboveMinRelay — AbsoluteFee', () {
    test('14 sat @ 140 vsize = 0.1 sat/vByte passes (boundary)', () {
      const fee = AbsoluteFee(14);
      expect(fee.aboveMinRelay(txSize: 140), isTrue);
    });

    test('13 sat @ 140 vsize fails (below floor)', () {
      const fee = AbsoluteFee(13);
      expect(fee.aboveMinRelay(txSize: 140), isFalse);
    });

    test('absolute fee with null txSize fails (pre-build state)', () {
      // Without a vsize we can't express the absolute as a rate; the
      // callers (cubit/bloc commit gates) treat this as not-yet-armed.
      const fee = AbsoluteFee(1000);
      expect(fee.aboveMinRelay(), isFalse);
    });

    test('absolute fee with zero txSize fails', () {
      const fee = AbsoluteFee(1000);
      expect(fee.aboveMinRelay(txSize: 0), isFalse);
    });
  });
}
