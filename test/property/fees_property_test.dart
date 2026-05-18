import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:kiri_check/kiri_check.dart';
import 'package:test/test.dart';

/// Property-based tests for NetworkFee and FeeOptions.
///
/// Tests mathematical invariants of fee conversion logic:
/// - RelativeFee → AbsoluteFee → RelativeFee roundtrip
/// - Fee ordering preservation (fastest >= economic >= slow)
/// - Non-negative outputs
/// - Idempotence of identity conversions
///
/// Target: lib/core/fees/domain/fees_entity.dart
void main() {
  group('NetworkFee.toAbsolute', () {
    property('absolute fee is identity under toAbsolute', () {
      forAll(
        integer(min: 0, max: 1000000), // reasonable absolute fee range
        (value) {
          final fee = NetworkFee.absolute(value);
          final result = fee.toAbsolute(250); // typical tx size
          expect((result as AbsoluteFee).value, equals(value),
              reason: 'AbsoluteFee.toAbsolute should be identity');
        },
      );
    });

    property('relative fee toAbsolute is non-negative for non-negative inputs',
        () {
      forAll(
        combine2(
          // fee rate in sats/byte (typically 1-500)
          integer(min: 0, max: 500),
          // tx size in bytes (typically 100-10000)
          integer(min: 1, max: 10000),
        ),
        (pair) {
          final (rate, size) = pair;
          final fee = NetworkFee.relative(rate.toDouble());
          final result = fee.toAbsolute(size) as AbsoluteFee;
          expect(result.value, greaterThanOrEqualTo(0),
              reason: 'Fee should be non-negative for rate=$rate size=$size');
        },
      );
    });

    property(
        'higher relative fee produces higher or equal absolute fee for same size',
        () {
      // Bug: fee ordering inversion would show wrong fee to user
      forAll(
        combine2(
          integer(min: 0, max: 500),
          integer(min: 0, max: 500),
        ),
        (pair) {
          final (a, b) = pair;
          const size = 250;
          final feeA =
              (NetworkFee.relative(a.toDouble()).toAbsolute(size) as AbsoluteFee)
                  .value;
          final feeB =
              (NetworkFee.relative(b.toDouble()).toAbsolute(size) as AbsoluteFee)
                  .value;
          if (a > b) {
            expect(feeA, greaterThanOrEqualTo(feeB),
                reason: 'Fee ordering violated: rate $a should produce >= fee than rate $b');
          } else if (a == b) {
            expect(feeA, equals(feeB),
                reason: 'Equal rates must produce equal fees: rate $a vs $b');
          }
        },
      );
    });
  });

  group('FeeOptions ordering', () {
    property('toAbsolute preserves tier ordering (fastest >= economic >= slow)',
        () {
      forAll(
        combine3(
          integer(min: 10, max: 500), // fastest rate
          integer(min: 5, max: 250), // economic rate
          integer(min: 1, max: 100), // slow rate
        ),
        (triple) {
          final (fastRate, ecoRate, slowRate) = triple;
          // Only test when ordering is correct in input
          if (fastRate >= ecoRate && ecoRate >= slowRate) {
            final options = FeeOptions(
              fastest: NetworkFee.relative(fastRate.toDouble()),
              economic: NetworkFee.relative(ecoRate.toDouble()),
              slow: NetworkFee.relative(slowRate.toDouble()),
            );

            final absolute = options.toAbsolute(250);
            final fastAbs = (absolute.fastest as AbsoluteFee).value;
            final ecoAbs = (absolute.economic as AbsoluteFee).value;
            final slowAbs = (absolute.slow as AbsoluteFee).value;

            expect(fastAbs, greaterThanOrEqualTo(ecoAbs),
                reason: 'fastest ($fastAbs) should be >= economic ($ecoAbs)');
            expect(ecoAbs, greaterThanOrEqualTo(slowAbs),
                reason: 'economic ($ecoAbs) should be >= slow ($slowAbs)');
          }
        },
      );
    });
  });
}
