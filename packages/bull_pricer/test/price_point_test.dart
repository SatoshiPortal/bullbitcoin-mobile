import 'package:bull_pricer/bull_pricer.dart';
import 'package:test/test.dart';

void main() {
  final time = DateTime.utc(2026, 11, 1);

  PricePoint cad(double fiatAmount) => PricePoint(
    currency: SupportedCurrency.cad,
    fiatAmount: fiatAmount,
    time: time,
  );

  group('PricePoint', () {
    test('accepts a positive price', () {
      final point = cad(108945.85);

      expect(point.fiatAmount, 108945.85);
      expect(point.time, time);
    });

    test('rejects a price that is not usable', () {
      for (final amount in [
        0.0,
        -1.0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(() => cad(amount), throwsArgumentError, reason: '$amount');
      }
    });

    test('is equal to another point with the same values', () {
      expect(cad(108945.85), cad(108945.85));
      expect(cad(108945.85).hashCode, cad(108945.85).hashCode);
      expect(cad(108945.85), isNot(cad(108945.86)));
    });
  });
}
