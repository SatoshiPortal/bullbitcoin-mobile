import 'package:bb_mobile/core/price/domain/usecases/convert_currency_to_sats_amount_usecase.dart';
import 'package:bb_mobile/core/price/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/price/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/init.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  /// The index price of one bitcoin, straight from the pricer.
  Future<double> indexPrice(String currencyCode) async {
    final currency = SupportedCurrency.tryFromCode(currencyCode);
    if (currency == null) fail('$currencyCode is not a pricer currency');
    return switch (await Pricer.getIndexPrice(
      network: BitcoinNetwork.mainnet,
      currency: currency,
    )) {
      Ok(:final value) => value.fiatAmount,
      Err(:final failure) => fail('No price for $currencyCode: $failure'),
    };
  }

  /// The converted value, or a test failure when there is no price.
  T converted<T>(Result<T, PricerFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => fail('No price: $failure'),
  };

  final getAvailableCurrenciesUsecase =
      locator<GetAvailableCurrenciesUsecase>();
  final convertCurrencyToSatsAmountUsecase =
      locator<ConvertCurrencyToSatsAmountUsecase>();
  final convertSatsToCurrencyAmountUsecase =
      locator<ConvertSatsToCurrencyAmountUsecase>();

  const currency = 'USD';

  group('Exchange Rate Integration Tests', () {
    group('have a working BullBitcoin API', () {
      test('with currencies we expect', () async {
        final expectedCurrencies = ['USD', 'CAD', 'MXN', 'CRC', 'EUR'];
        final currencies = await getAvailableCurrenciesUsecase.execute();

        for (final currency in expectedCurrencies) {
          expect(
            currencies.contains(currency),
            true,
            reason: 'Currency $currency not found',
          );
        }
      });
      test('with prices for available currencies', () async {
        final currencies = await getAvailableCurrenciesUsecase.execute();
        for (final currency in currencies) {
          try {
            final price = await indexPrice(currency);
            debugPrint('Price for $currency: $price');

            expect(price, isNonZero);
            expect(price, isPositive);
          } catch (e) {
            fail('Failed to get price for $currency: $e');
          }
        }
      });
    });

    group('have working conversion use cases', () {
      // The BTC price is live and ticks between calls (and a slow setUpAll —
      // e.g. Tor bootstrapping — can delay these tests by tens of seconds), so
      // the reference price is fetched right next to each conversion and
      // compared with a ~1% tolerance rather than for exact equality.
      test('that get the price of one bitcoin', () async {
        final amountSat = ConversionConstants.satsAmountOfOneBitcoin;

        final amount = converted(
          await convertSatsToCurrencyAmountUsecase.execute(
            currencyCode: currency,
            amountSat: amountSat,
          ),
        );
        final bitcoinPrice = await indexPrice(currency);

        debugPrint(
          'Converted $amountSat sats to $amount $currency '
          '(reference price $bitcoinPrice)',
        );

        expect(amount, closeTo(bitcoinPrice, bitcoinPrice * 0.01));
      });

      test('that converts currency to sats', () async {
        const amount = 123.0;

        final sats = converted(
          await convertCurrencyToSatsAmountUsecase.execute(
            currencyCode: currency,
            amountFiat: amount,
          ),
        );
        final bitcoinPrice = await indexPrice(currency);

        debugPrint('Converted $amount $currency to $sats sats');

        final expectedSats = amount * 100000000 / bitcoinPrice;

        expect(sats.toInt(), closeTo(expectedSats, expectedSats * 0.01));
      });

      test('that converts sats to currency', () async {
        final sats = BigInt.from(150000);

        final amount = converted(
          await convertSatsToCurrencyAmountUsecase.execute(
            currencyCode: currency,
            amountSat: sats,
          ),
        );
        final bitcoinPrice = await indexPrice(currency);

        debugPrint('Converted $sats sats to $amount $currency');

        final expectedAmount = sats / BigInt.from(100000000) * bitcoinPrice;
        expect(amount, closeTo(expectedAmount, expectedAmount * 0.01));
      });
    });
  });
}
