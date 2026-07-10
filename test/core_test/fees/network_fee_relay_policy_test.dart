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

  group('NetworkFee.aboveMinRelay — dynamic floor (live minimumFee)', () {
    test('a rate at the static floor fails against a higher dynamic floor', () {
      // 0.1 sat/vB (25 kwu) clears the static floor but not a congested
      // 0.5 sat/vB (125 kwu) minimum reported by mempool.
      const fee = RelativeFee(25);
      expect(fee.aboveMinRelay(), isTrue);
      expect(fee.aboveMinRelay(floorSatPerKwu: 125), isFalse);
    });

    test('a rate at the dynamic floor passes', () {
      const fee = RelativeFee(125);
      expect(fee.aboveMinRelay(floorSatPerKwu: 125), isTrue);
    });

    test('absolute fee compared against the dynamic floor (kwu space)', () {
      // 0.5 sat/vB floor = 125 kwu. 70 sat @ 140 vsize = 0.5 sat/vB → passes;
      // 69 sat → below.
      expect(
        const AbsoluteFee(70).aboveMinRelay(txSize: 140, floorSatPerKwu: 125),
        isTrue,
      );
      expect(
        const AbsoluteFee(69).aboveMinRelay(txSize: 140, floorSatPerKwu: 125),
        isFalse,
      );
    });
  });

  group(
    'NetworkFee.aboveMinRelay — stale-vsize divergence (createTx re-assert)',
    () {
      // The send commit gate (finalizeArmedCustomFee) checks an ABSOLUTE custom
      // fee against the PREVIOUS build's bitcoinTxSize (or a 140 fallback). If
      // the real tx is larger, an absolute fee that cleared the gate at the
      // stale/small vsize lands BELOW the relay floor at the actual vsize.
      // createTransaction now re-asserts the floor against the freshly built
      // fee/vsize before broadcast — these cases pin that exact divergence.
      test(
        '14 sat clears the floor at the stale 140 vsize but fails at 250',
        () {
          const fee = AbsoluteFee(14);
          // The gate saw 0.1 sat/vB (14/140) and let it through…
          expect(fee.aboveMinRelay(txSize: 140), isTrue);
          // …but the real tx weighed 250 vbytes → 0.056 sat/vB, below the floor.
          expect(fee.aboveMinRelay(txSize: 250), isFalse);
        },
      );

      test('a fee that clears the floor at both vsizes is unaffected', () {
        // 25 sat @ 250 vsize = 0.1 sat/vB exactly — still relayable at the real
        // size, so the re-assert is a no-op for honest fees.
        const fee = AbsoluteFee(25);
        expect(fee.aboveMinRelay(txSize: 140), isTrue);
        expect(fee.aboveMinRelay(txSize: 250), isTrue);
      });
    },
  );
}
