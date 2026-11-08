import 'package:bb_mobile/init.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  group('Exchange Rate Integration Tests', () {
    test('the Bull Bitcoin API prices every supported currency', () async {
      for (final currency in SupportedCurrency.values) {
        final price = await Pricer.getIndexPrice(
          network: BitcoinNetwork.mainnet,
          currency: currency,
        );
        switch (price) {
          case Ok(:final value):
            debugPrint('Price for ${currency.code}: ${value.fiatAmount}');
            expect(value.fiatAmount, isPositive);
          case Err(:final failure):
            fail('No price for ${currency.code}: $failure');
        }
      }
    });

    test('the Bull Bitcoin API has a price history', () async {
      final history = await Pricer.getPriceHistory(
        network: BitcoinNetwork.mainnet,
        currency: SupportedCurrency.usd,
      );
      switch (history) {
        case Ok(:final value):
          expect(value, isNotEmpty);
        case Err(:final failure):
          fail('No price history: $failure');
      }
    });
  });
}
