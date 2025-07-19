import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_currency_to_sats_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  final bitcoinPriceDatasource = locator<BullbitcoinApiDatasource>(
    instanceName: 'mainnetExchangeApiDatasource',
  );
  final getAvailableCurrenciesUsecase =
      locator<GetAvailableCurrenciesUsecase>();
  final convertCurrencyToSatsAmountUsecase =
      locator<ConvertCurrencyToSatsAmountUsecase>();
  final convertSatsToCurrencyAmountUsecase =
      locator<ConvertSatsToCurrencyAmountUsecase>();

  const currency = 'USD';
  final bitcoinPrice = await bitcoinPriceDatasource.getPrice(currency);

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
            final price = await bitcoinPriceDatasource.getPrice(currency);
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
      test('that get the price of one bitcoin', () async {
        final amountSat = ConversionConstants.satsAmountOfOneBitcoin;

        final amount = await convertSatsToCurrencyAmountUsecase.execute(
          currencyCode: currency,
          amountSat: amountSat,
        );

        debugPrint('Converted $amountSat sats to $amount $currency');

        expect(amount, bitcoinPrice);
      });

      test('that converts currency to sats', () async {
        const amount = 123.0;

        final sats = await convertCurrencyToSatsAmountUsecase.execute(
          currencyCode: currency,
          amountFiat: amount,
        );

        debugPrint('Converted $amount $currency to $sats sats');

        final expectedSats = BigInt.from((amount * 100000000) ~/ bitcoinPrice);

        expect(sats, expectedSats);
      });

      test('that converts sats to currency', () async {
        final sats = BigInt.from(150000);

        final amount = await convertSatsToCurrencyAmountUsecase.execute(
          currencyCode: currency,
          amountSat: sats,
        );

        debugPrint('Converted $sats sats to $amount $currency');

        final expectedAmount = sats / BigInt.from(100000000) * bitcoinPrice;
        expect(amount, expectedAmount);
      });
    });
  });
}
