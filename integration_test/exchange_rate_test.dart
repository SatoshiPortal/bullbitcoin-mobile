import 'initialization_result.dart';

import 'package:bb_mobile/init.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_pricer/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) {
    requireSuccessfulBullInitialization(await Bull.init());
  }

  group('Exchange Rate Integration Tests', () {
    late FakePriceApi api;

    setUp(() async {
      api = await FakePriceApi.start();
      addTearDown(api.close);
    });

    test('decodes a quote for every supported currency', () async {
      for (final currency in SupportedCurrency.values) {
        final price = await Pricer.getIndexPrice(
          network: BitcoinNetwork.mainnet,
          currency: currency,
        );
        switch (price) {
          case Ok(:final value):
            expect(value.currency, currency);
            expect(value.fiatAmount, mainnetIndexPrice / 100);
          case Err(:final failure):
            fail('No price for ${currency.code}: $failure');
        }
      }
      expect(
        api.requests
            .where((request) => request.method == 'getRate')
            .map((request) => request.params['toCurrency']),
        unorderedEquals(
          SupportedCurrency.values.map((currency) => currency.code),
        ),
      );
    });

    test('decodes historical quotes', () async {
      final history = await Pricer.getPriceHistory(
        network: BitcoinNetwork.mainnet,
        currency: SupportedCurrency.usd,
      );
      switch (history) {
        case Ok(:final value):
          expect(value, isNotEmpty);
          expect(
            value.map((point) => point.currency),
            everyElement(SupportedCurrency.usd),
          );
          expect(value.last.fiatAmount, mainnetIndexPrice / 100);
          expect(api.callsTo('getIndexRateHistory'), greaterThan(0));
        case Err(:final failure):
          fail('No price history: $failure');
      }
    });
  });
}
