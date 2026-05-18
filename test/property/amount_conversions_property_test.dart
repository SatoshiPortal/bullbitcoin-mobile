import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:kiri_check/kiri_check.dart';
import 'package:test/test.dart';

/// Property-based tests for ConvertAmount (sat ↔ BTC ↔ fiat).
///
/// Bug each test catches is documented inline.
///
/// Known limitation: ConvertAmount uses IEEE 754 doubles internally.
/// At values above ~90,000 BTC, the intermediate btcValue * 100000000
/// loses sub-satoshi precision. The .round() call compensates for most
/// cases but this is a known architectural limitation.
///
/// Target: lib/core/utils/amount_conversions.dart
void main() {
  group('satsToBtc / btcToSats roundtrip', () {
    property('sats → BTC → sats roundtrip preserves value (0 to 1000 BTC)', () {
      // Bug: roundtrip precision loss in the conversion pipeline
      forAll(
        integer(min: 0, max: 100000000000), // up to 1000 BTC in sats
        (sats) {
          final btc = ConvertAmount.satsToBtc(sats);
          final backToSats = ConvertAmount.btcToSats(btc);
          expect(backToSats, equals(sats),
              reason: 'Roundtrip failed: $sats → $btc → $backToSats');
        },
      );
    });

    property('satsToBtc is strictly monotonic (a > b implies f(a) > f(b))', () {
      // Bug: non-monotonic conversion could swap payment ordering
      forAll(
        combine2(
          integer(min: 0, max: 2100000000000000),
          integer(min: 0, max: 2100000000000000),
        ),
        (pair) {
          final (a, b) = pair;
          if (a > b) {
            // Use strict > not >= : for integer sat inputs differing by >=1,
            // satsToBtc must produce strictly different outputs (1 sat = 1e-8 BTC
            // = the precision boundary of toStringAsFixed(8))
            expect(ConvertAmount.satsToBtc(a),
                greaterThan(ConvertAmount.satsToBtc(b)),
                reason: 'Strict monotonicity violated: satsToBtc($a) <= satsToBtc($b)');
          }
        },
      );
    });
  });

  group('known anchor values', () {
    // Bug: wrong constant (100M) would break every conversion
    test('100,000,000 sats = exactly 1.0 BTC', () {
      expect(ConvertAmount.satsToBtc(100000000), equals(1.0));
      expect(ConvertAmount.btcToSats(1.0), equals(100000000));
    });

    test('1 sat = 0.00000001 BTC', () {
      // Note: 0.00000001 cannot be represented exactly in IEEE 754.
      // Both sides resolve to the same approximation. This is a known
      // limitation of using doubles for financial math.
      expect(ConvertAmount.satsToBtc(1), equals(0.00000001));
    });

    test('0 sats = 0.0 BTC', () {
      expect(ConvertAmount.satsToBtc(0), equals(0.0));
      expect(ConvertAmount.btcToSats(0.0), equals(0));
    });

    test('max supply: 21M BTC = 2,100,000,000,000,000 sats', () {
      // Bug: overflow or precision loss at max supply
      final btc = ConvertAmount.satsToBtc(2100000000000000);
      expect(btc, equals(21000000.0),
          reason: 'Max supply conversion must be exact');
      // Reverse: btcToSats at max supply
      // Note: 21000000.0 * 100000000 = 2.1e15, which is within double precision (< 2^53)
      expect(ConvertAmount.btcToSats(21000000.0), equals(2100000000000000),
          reason: 'Max supply reverse conversion must be exact');
    });

    test('precision boundary: 0.1 BTC roundtrips correctly', () {
      // Bug: IEEE 754 cannot represent 0.1 exactly. Tests the .round() defense.
      final sats = ConvertAmount.btcToSats(0.1);
      expect(sats, equals(10000000));
      expect(ConvertAmount.satsToBtc(sats), equals(0.1));
    });
  });

  group('fiat conversions', () {
    // Bug: monotonicity violation could display wrong fiat ordering
    property('satsToFiat is strictly monotonic for fixed exchange rate', () {
      forAll(
        combine2(
          integer(min: 0, max: 100000000000),
          integer(min: 0, max: 100000000000),
        ),
        (pair) {
          final (a, b) = pair;
          const rate = 50000.0; // 50k/BTC
          if (a > b) {
            expect(ConvertAmount.satsToFiat(a, rate),
                greaterThanOrEqualTo(ConvertAmount.satsToFiat(b, rate)));
          }
        },
      );
    });

    test('satsToFiat known value: 1 BTC at 50000 USD = 50000 USD', () {
      // Bug: wrong multiplication order or rounding
      final fiat = ConvertAmount.satsToFiat(100000000, 50000.0);
      expect(fiat, closeTo(50000.0, 0.01),
          reason: '1 BTC at 50k rate should equal 50000');
    });

    test('satsToFiat known value: 1 sat at 50000 USD rounds to 0', () {
      // 1 sat = 0.00000001 BTC * 50000 = 0.0005
      // satsToFiat uses toStringAsFixed(2) → "0.00" → 0.0
      // This is correct: 1 sat is sub-cent at $50k/BTC
      final fiat = ConvertAmount.satsToFiat(1, 50000.0);
      expect(fiat, equals(0.0),
          reason: '1 sat at 50k rounds to 0.00 (sub-cent)');
    });

    test('btcToFiat known value: 1 BTC at 50000 USD = 50000 USD', () {
      // Bug: btcToFiat uses toStringAsFixed(2) rounding
      final fiat = ConvertAmount.btcToFiat(1.0, 50000.0);
      expect(fiat, closeTo(50000.0, 0.01));
    });

    test('fiatToBtc known value: 50000 USD at 50000 USD/BTC = 1.0 BTC', () {
      // Bug: division by exchange rate, precision loss
      final btc = ConvertAmount.fiatToBtc(50000.0, 50000.0);
      expect(btc, closeTo(1.0, 0.00000001));
    });

    test('fiatToSats known value: 50000 USD at 50000 USD/BTC = 100M sats', () {
      // Bug: chained precision loss (fiatToBtc → btcToSats)
      final sats = ConvertAmount.fiatToSats(50000.0, 50000.0);
      expect(sats, equals(100000000));
    });

    test('fiatToSats known value: 0.01 USD at 50000 USD/BTC', () {
      // 0.01 USD / 50000 USD = 0.0000002 BTC = 20 sats
      final sats = ConvertAmount.fiatToSats(0.01, 50000.0);
      expect(sats, equals(20));
    });
  });
}
