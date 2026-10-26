import 'package:bull_pricer/bull_pricer.dart';
import 'package:test/test.dart';

void main() {
  group('SupportedCurrency.tryFromCode', () {
    test('finds every supported currency by its code', () {
      for (final currency in SupportedCurrency.values) {
        expect(SupportedCurrency.tryFromCode(currency.code), currency);
      }
    });

    test('ignores the case of the code', () {
      expect(SupportedCurrency.tryFromCode('cad'), SupportedCurrency.cad);
      expect(SupportedCurrency.tryFromCode('Usd'), SupportedCurrency.usd);
    });

    test('returns null for a code the price service does not quote', () {
      for (final code in ['GBP', 'BTC', 'CA', '']) {
        expect(SupportedCurrency.tryFromCode(code), isNull, reason: code);
      }
    });
  });
}
