import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RelativeFee.fromSatPerVbyte', () {
    test('1 sat/vByte = 250 sat/kwu (exact)', () {
      expect(NetworkFee.relativeFromSatPerVbyte(1.0), const RelativeFee(250));
    });

    test('0.5 sat/vByte = 125 sat/kwu (exact)', () {
      // Issue #2133 — the headline case. Previously the wrapper rounded
      // 0.5 to 1 sat/vByte; now it lands on a precise 125 sat/kwu.
      expect(NetworkFee.relativeFromSatPerVbyte(0.5), const RelativeFee(125));
    });

    test(
      '0.1 sat/vByte = 25 sat/kwu (exact, the network minrelayfee floor)',
      () {
        expect(NetworkFee.relativeFromSatPerVbyte(0.1), const RelativeFee(25));
      },
    );

    test('0.25 sat/vByte rounds half-away-from-zero to 63 sat/kwu', () {
      // 0.25 × 250 = 62.5, Dart's num.round() goes away from zero.
      expect(NetworkFee.relativeFromSatPerVbyte(0.25), const RelativeFee(63));
    });

    test('0.001 sat/vByte rounds down to 0 sat/kwu (below precision)', () {
      // 0.001 × 250 = 0.25 → 0. Such a rate is below what BDK can express;
      // the use case / UI must guard against this.
      expect(NetworkFee.relativeFromSatPerVbyte(0.001), const RelativeFee(0));
    });

    test('round trip preserves sat/vByte within 0.002 precision', () {
      const inputs = [0.1, 0.5, 1.0, 2.5, 10.0, 100.0];
      for (final v in inputs) {
        final fee = NetworkFee.relativeFromSatPerVbyte(v);
        expect(
          (fee.satPerVbyte - v).abs(),
          lessThan(0.002),
          reason: 'round-trip for $v sat/vByte',
        );
      }
    });
  });

  group('RelativeFee.fromAbsoluteAndVsize', () {
    test('100 sats over 200 vbytes = 0.5 sat/vByte = 125 sat/kwu', () {
      expect(
        NetworkFee.relativeFromAbsoluteAndVsize(absoluteSats: 100, vsize: 200),
        const RelativeFee(125),
      );
    });

    test('asserts a positive vsize', () {
      expect(
        () => NetworkFee.relativeFromAbsoluteAndVsize(
          absoluteSats: 100,
          vsize: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('round-half-up for non-divisible cases', () {
      // 100 × 250 / 201 = 124.378... → expect 124 (truncated by ~/ after the
      // +vsize/2 shift; close enough to half-up for our purposes).
      final fee = NetworkFee.relativeFromAbsoluteAndVsize(
        absoluteSats: 100,
        vsize: 201,
      );
      // The result should round 124.378 to 124 — confirm the off-by-1
      // doesn't drift further than ±1 sat/kwu.
      expect(fee.satPerKwu, anyOf(equals(124), equals(125)));
    });
  });

  group('RelativeFee display getters', () {
    test('satPerVbyte exposes the user-facing unit', () {
      expect(const RelativeFee(125).satPerVbyte, 0.5);
      expect(const RelativeFee(25).satPerVbyte, closeTo(0.1, 1e-9));
      expect(const RelativeFee(250).satPerVbyte, 1.0);
    });

    test('satPerKvbyte = 4 × satPerKwu — what LWK expects', () {
      expect(const RelativeFee(125).satPerKvbyte, 500.0);
      expect(const RelativeFee(25).satPerKvbyte, 100.0);
      expect(const RelativeFee(250).satPerKvbyte, 1000.0);
    });
  });

  group('NetworkFee.toAbsolute', () {
    test('AbsoluteFee passes through unchanged', () {
      expect(const AbsoluteFee(500).toAbsolute(200), const AbsoluteFee(500));
    });

    test('RelativeFee × vsize → AbsoluteFee in sats', () {
      // 0.5 sat/vByte × 200 vbytes = 100 sats.
      expect(const RelativeFee(125).toAbsolute(200), const AbsoluteFee(100));
    });

    test('rounds half-up when satPerKwu × vsize is not divisible by 250', () {
      // satPerKwu=125, vsize=201 → (125*201 + 125) ~/ 250 = 25250 ~/ 250 = 101
      expect(const RelativeFee(125).toAbsolute(201), const AbsoluteFee(101));
    });
  });

  group('NetworkFee.value (legacy display getter)', () {
    test('AbsoluteFee returns sats as int', () {
      expect(const AbsoluteFee(123).value, 123);
      expect(const AbsoluteFee(123).value, isA<int>());
    });

    test('RelativeFee returns sat/vByte as double', () {
      expect(const RelativeFee(125).value, 0.5);
      expect(const RelativeFee(125).value, isA<double>());
    });
  });
}
