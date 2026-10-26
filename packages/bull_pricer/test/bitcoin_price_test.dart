import 'package:bull_pricer/bull_pricer.dart';
import 'package:test/test.dart';

void main() {
  final fetchedAt = DateTime.utc(2026, 10, 26, 12);

  BitcoinPrice cad(double fiatAmount, {DateTime? at}) => BitcoinPrice(
    currency: SupportedCurrency.cad,
    fiatAmount: fiatAmount,
    fetchedAt: at ?? fetchedAt,
  );

  group('BitcoinPrice', () {
    test('accepts a positive price', () {
      final price = cad(114214.20);

      expect(price.fiatAmount, 114214.20);
      expect(price.fetchedAt, fetchedAt);
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

    test('is equal to another price with the same values', () {
      expect(cad(114214.20), cad(114214.20));
      expect(cad(114214.20).hashCode, cad(114214.20).hashCode);
    });

    test('differs when the amount, currency or fetch time differs', () {
      expect(cad(114214.20), isNot(cad(114214.21)));
      expect(
        cad(114214.20),
        isNot(
          BitcoinPrice(
            currency: SupportedCurrency.usd,
            fiatAmount: 114214.20,
            fetchedAt: fetchedAt,
          ),
        ),
      );
      expect(
        cad(114214.20),
        isNot(cad(114214.20, at: fetchedAt.add(const Duration(seconds: 1)))),
      );
    });

    test('reads as the amount per bitcoin and when it was fetched', () {
      expect(
        cad(114214.20).toString(),
        '114214.2 CAD/BTC at 2026-10-26T12:00:00.000Z',
      );
    });
  });
}
