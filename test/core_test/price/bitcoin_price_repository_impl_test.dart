import 'dart:async';

import 'package:bb_mobile/core/price/data/bitcoin_price_repository_impl.dart';
import 'package:bb_mobile/core/price/data/datasources/bullbitcoin_price_datasource.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPriceDatasource extends Mock implements BullbitcoinPriceDatasource {}

void main() {
  final oneBtc = BigInt.from(100000000);

  late _MockPriceDatasource datasource;
  late BitcoinPriceRepositoryImpl repository;

  Future<double> priceCall(String currency) => datasource.getPrice(currency);

  setUp(() {
    datasource = _MockPriceDatasource();
    when(() => priceCall('USD')).thenAnswer((_) async => 70000);
    when(() => priceCall('CAD')).thenAnswer((_) async => 95000);
  });

  // The pricer serves every user: a price is fetched at most once a minute per
  // currency, whatever the number of screens and use cases reading it.
  test('a price read again within a minute reuses the fetched one', () {
    fakeAsync((time) {
      repository = BitcoinPriceRepositoryImpl(
        bullbitcoinPriceDatasource: datasource,
      );
      final values = <double>[];
      for (var i = 0; i < 5; i++) {
        repository
            .getCurrencyValue(amountSat: oneBtc, currency: 'USD')
            .then(values.add);
        time.elapse(const Duration(seconds: 10));
      }
      expect(values, [70000, 70000, 70000, 70000, 70000]);
      verify(() => priceCall('USD')).called(1);
    });
  });

  test('a price older than a minute is fetched again', () {
    fakeAsync((time) {
      repository = BitcoinPriceRepositoryImpl(
        bullbitcoinPriceDatasource: datasource,
      );
      repository.getCurrencyValue(amountSat: oneBtc, currency: 'USD');
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 60));
      repository.getCurrencyValue(amountSat: oneBtc, currency: 'USD');
      time.flushMicrotasks();
      verify(() => priceCall('USD')).called(2);
    });
  });

  test('simultaneous reads share one request', () {
    fakeAsync((time) {
      final answer = Completer<double>();
      when(() => priceCall('USD')).thenAnswer((_) => answer.future);
      repository = BitcoinPriceRepositoryImpl(
        bullbitcoinPriceDatasource: datasource,
      );
      final values = <BigInt>[];
      for (var i = 0; i < 8; i++) {
        repository
            .getSatsValue(amountFiat: 70, currency: 'USD')
            .then(values.add);
      }
      answer.complete(70000);
      time.flushMicrotasks();
      verify(() => priceCall('USD')).called(1);
      expect(values, List.filled(8, BigInt.from(100000)));
    });
  });

  test('each currency has its own minute', () {
    fakeAsync((time) {
      repository = BitcoinPriceRepositoryImpl(
        bullbitcoinPriceDatasource: datasource,
      );
      repository.getCurrencyValue(amountSat: oneBtc, currency: 'USD');
      repository.getCurrencyValue(amountSat: oneBtc, currency: 'CAD');
      time.flushMicrotasks();
      verify(() => priceCall('USD')).called(1);
      verify(() => priceCall('CAD')).called(1);
    });
  });

  test('a failed fetch is not retried within the minute and reads fail', () {
    fakeAsync((time) {
      // The datasource reports an unreachable pricer as a zero rate.
      when(() => priceCall('USD')).thenAnswer((_) async => 0);
      repository = BitcoinPriceRepositoryImpl(
        bullbitcoinPriceDatasource: datasource,
      );
      repository.getCurrencyValue(amountSat: oneBtc, currency: 'USD');
      time.flushMicrotasks();
      when(() => priceCall('USD')).thenAnswer((_) async => 70000);

      double? value;
      time.elapse(const Duration(seconds: 59));
      repository
          .getCurrencyValue(amountSat: oneBtc, currency: 'USD')
          .then((v) => value = v);
      time.flushMicrotasks();
      verify(() => priceCall('USD')).called(1);
      expect(value, 0);

      time.elapse(const Duration(seconds: 1));
      repository
          .getCurrencyValue(amountSat: oneBtc, currency: 'USD')
          .then((v) => value = v);
      time.flushMicrotasks();
      verify(() => priceCall('USD')).called(1);
      expect(value, 70000);
    });
  });

  test('a lapsed price is never served when the pricer fails', () {
    fakeAsync((time) {
      repository = BitcoinPriceRepositoryImpl(
        bullbitcoinPriceDatasource: datasource,
      );
      repository.getCurrencyValue(amountSat: oneBtc, currency: 'USD');
      time.flushMicrotasks();
      when(() => priceCall('USD')).thenAnswer((_) async => 0);
      time.elapse(const Duration(seconds: 61));

      double? value;
      repository
          .getCurrencyValue(amountSat: oneBtc, currency: 'USD')
          .then((v) => value = v);
      time.flushMicrotasks();
      expect(value, 0, reason: 'an error, not the minute-old 70000');
    });
  });

  test('a thrown fetch fails reads for the minute without new requests', () {
    fakeAsync((time) {
      when(() => priceCall('USD')).thenThrow(Exception('offline'));
      repository = BitcoinPriceRepositoryImpl(
        bullbitcoinPriceDatasource: datasource,
      );
      Object? error;
      repository
          .getCurrencyValue(amountSat: oneBtc, currency: 'USD')
          .catchError((Object e) {
            error = e;
            return 0.0;
          });
      time.flushMicrotasks();
      expect(error, isA<Exception>());

      double? value;
      repository
          .getCurrencyValue(amountSat: oneBtc, currency: 'USD')
          .then((v) => value = v);
      time.flushMicrotasks();
      expect(value, 0);
      verify(() => priceCall('USD')).called(1);
    });
  });
}
