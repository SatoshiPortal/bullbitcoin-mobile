import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every currency has exactly one market, in picker order', () {
    expect(
      ExchangeCatalog.markets.map((m) => m.currency).toList(),
      FiatCurrency.values,
    );
    for (final currency in FiatCurrency.values) {
      expect(ExchangeCatalog.market(currency).currency, currency);
    }
  });

  group('currency to jurisdiction', () {
    final cases = <(FiatCurrency, Jurisdiction)>[
      (FiatCurrency.cad, Jurisdiction.canada),
      (FiatCurrency.eur, Jurisdiction.europe),
      (FiatCurrency.mxn, Jurisdiction.mexico),
      (FiatCurrency.crc, Jurisdiction.costaRica),
      // The only USD rails (SINPE IBAN USD, CR IBAN USD) are Costa Rican.
      (FiatCurrency.usd, Jurisdiction.costaRica),
      (FiatCurrency.ars, Jurisdiction.argentina),
      (FiatCurrency.cop, Jurisdiction.colombia),
    ];
    for (final (currency, jurisdiction) in cases) {
      test('${currency.code} -> ${jurisdiction.name}', () {
        expect(ExchangeCatalog.jurisdictionOf(currency), jurisdiction);
      });
    }
  });

  group('parse', () {
    test('reads every market code, whatever the case or padding', () {
      for (final market in ExchangeCatalog.markets) {
        final code = market.currency.code;
        expect(ExchangeCatalog.parse(code), KnownCurrency(market));
        expect(
          ExchangeCatalog.parse(' ${code.toLowerCase()} '),
          KnownCurrency(market),
        );
      }
    });

    test('an unknown code is UnknownCurrency with the raw value', () {
      expect(ExchangeCatalog.parse('JPY'), const UnknownCurrency('JPY'));
      expect(ExchangeCatalog.parse(''), const UnknownCurrency(''));
      expect(ExchangeCatalog.parse('BTC'), const UnknownCurrency('BTC'));
    });

    test(
      'legacyCurrencyOrFallback reads absent and unknown as the fallback',
      () {
        expect(
          ExchangeCatalog.legacyCurrencyOrFallback('EUR'),
          FiatCurrency.eur,
        );
        expect(
          ExchangeCatalog.legacyCurrencyOrFallback('JPY'),
          ExchangeCatalog.legacyNoMarketFallback.currency,
        );
        expect(
          ExchangeCatalog.legacyCurrencyOrFallback(null),
          ExchangeCatalog.legacyNoMarketFallback.currency,
        );
      },
    );
  });

  test('every jurisdiction has a market', () {
    for (final jurisdiction in Jurisdiction.values) {
      expect(ExchangeCatalog.marketsIn(jurisdiction), isNotEmpty);
    }
    expect(
      ExchangeCatalog.marketsIn(Jurisdiction.costaRica).map((m) => m.currency),
      [FiatCurrency.usd, FiatCurrency.crc],
    );
  });
}
