import 'dart:async';

import 'package:bb_mobile/core/exchange/data/datasources/bull_bitcoin_price_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_currency_to_sats_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/storage/seed/sqlite_seed.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:payjoin_flutter/src/generated/frb_generated.dart';
import 'package:test/test.dart';

void main() {
  late BullBitcoinPriceDatasource bitcoinPriceDatasource;
  late GetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase;
  late ConvertCurrencyToSatsAmountUsecase convertCurrencyToSatsAmountUsecase;
  late ConvertSatsToCurrencyAmountUsecase convertSatsToCurrencyAmountUsecase;

  setUpAll(() async {
    await Future.wait([dotenv.load(isOptional: true), core.init()]);

    await AppLocator.setup();

    await locator<SqliteDatabase>().seedTables();

    bitcoinPriceDatasource = locator.get<BullBitcoinPriceDatasource>();
    getAvailableCurrenciesUsecase =
        locator.get<GetAvailableCurrenciesUsecase>();
    convertCurrencyToSatsAmountUsecase =
        locator.get<ConvertCurrencyToSatsAmountUsecase>();
    convertSatsToCurrencyAmountUsecase =
        locator.get<ConvertSatsToCurrencyAmountUsecase>();
  });

  setUp(() {});

  group('Exchange Rate Integration Tests', () {
    group('have a working BullBitcoin API', () {
      test('with currencies we expect', () async {
        final expectedCurrencies = ['USD', 'CAD', 'INR', 'CRC', 'EUR'];
        final currencies = await getAvailableCurrenciesUsecase.execute();

        for (final currency in expectedCurrencies) {
          expect(currencies.contains(currency), true);
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
      const currency = 'USD';
      late double bitcoinPrice;

      setUp(() async {
        bitcoinPrice = await bitcoinPriceDatasource.getPrice(currency);
      });

      test('that get the price of one bitcoin', () async {
        final amountSat = ConversionConstants.satsAmountOfOneBitcoin;

        final amount = await convertSatsToCurrencyAmountUsecase.execute(
          currencyCode: currency,
          amountSat: amountSat,
        );

        debugPrint('Converted $amountSat sats to $amount $currency');

        expect(bitcoinPrice, amount);
      });

      test('that converts currency to sats', () async {
        const amount = 123.0;

        final sats = await convertCurrencyToSatsAmountUsecase.execute(
          currencyCode: currency,
          amountFiat: amount,
        );

        debugPrint('Converted $amount $currency to $sats sats');

        final expectedSats = BigInt.from((amount * 100000000) ~/ bitcoinPrice);

        expect(expectedSats, sats);
      });

      test('that converts sats to currency', () async {
        final sats = BigInt.from(150000);

        final amount = await convertSatsToCurrencyAmountUsecase.execute(
          currencyCode: currency,
          amountSat: sats,
        );

        debugPrint('Converted $sats sats to $amount $currency');

        final expectedAmount = sats / BigInt.from(100000000) * bitcoinPrice;
        expect(expectedAmount, amount);
      });
    });
  });
}
