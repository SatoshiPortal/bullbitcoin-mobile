import 'dart:async';

import 'package:bb_mobile/core/price/data/bitcoin_price_repository_impl.dart';
import 'package:bb_mobile/core/price/data/datasources/bullbitcoin_price_datasource.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPriceDatasource extends Mock implements BullbitcoinPriceDatasource {}

void main() {
  final oneBtc = BigInt.from(100000000);

  late _MockPriceDatasource datasource;

  Future<double> priceCall(String currency) => datasource.getPrice(currency);

  setUp(() {
    datasource = _MockPriceDatasource();
    when(() => priceCall('USD')).thenAnswer((_) async => 70000);
    when(() => priceCall('CAD')).thenAnswer((_) async => 95000);
  });

  /// Runs [body] in fake time. The wall clock is fake time plus [wallShift],
  /// which a test moves to imitate the device clock being changed; the
  /// monotonic tick is fake time minus [asleep], imitating a monotonic clock
  /// that does not count deep sleep.
  void inFakeTime(
    void Function(
      FakeAsync time,
      BitcoinPriceRepositoryImpl repository,
      void Function(Duration) shiftWallClock,
      void Function(Duration) sleep,
    )
    body,
  ) {
    fakeAsync((time) {
      var wallShift = Duration.zero;
      var asleep = Duration.zero;
      final start = clock.now();
      withClock(Clock(() => start.add(time.elapsed + wallShift)), () {
        final repository = BitcoinPriceRepositoryImpl(
          bullbitcoinPriceDatasource: datasource,
          monotonicElapsed: () => time.elapsed - asleep,
        );
        body(time, repository, (shift) => wallShift += shift, (duration) {
          asleep += duration;
          time.elapse(duration);
        });
      });
    });
  }

  double? read(FakeAsync time, BitcoinPriceRepositoryImpl repository) {
    double? value;
    repository
        .getCurrencyValue(amountSat: oneBtc, currency: 'USD')
        .then((v) => value = v);
    time.flushMicrotasks();
    return value;
  }

  // The pricer serves every user: while a price fetched less than a minute
  // ago is held, it is not asked again for that currency.
  test('a price read again within a minute reuses the fetched one', () {
    inFakeTime((time, repository, _, _) {
      for (var i = 0; i < 6; i++) {
        expect(read(time, repository), 70000);
        time.elapse(const Duration(seconds: 9));
      }
      verify(() => priceCall('USD')).called(1);
    });
  });

  test('a price is fetched again at exactly one minute', () {
    inFakeTime((time, repository, _, _) {
      read(time, repository);
      time.elapse(const Duration(seconds: 59, milliseconds: 999));
      read(time, repository);
      verify(() => priceCall('USD')).called(1);
      time.elapse(const Duration(milliseconds: 1));
      read(time, repository);
      verify(() => priceCall('USD')).called(1);
    });
  });

  test('simultaneous reads share one request', () {
    inFakeTime((time, repository, _, _) {
      final answer = Completer<double>();
      when(() => priceCall('USD')).thenAnswer((_) => answer.future);
      final values = <double>[];
      for (var i = 0; i < 8; i++) {
        repository
            .getCurrencyValue(amountSat: oneBtc, currency: 'USD')
            .then(values.add);
      }
      answer.complete(70000);
      time.flushMicrotasks();
      verify(() => priceCall('USD')).called(1);
      expect(values, List.filled(8, 70000.0));
    });
  });

  test('each currency has its own minute', () {
    inFakeTime((time, repository, _, _) {
      repository.getCurrencyValue(amountSat: oneBtc, currency: 'USD');
      repository.getCurrencyValue(amountSat: oneBtc, currency: 'CAD');
      time.flushMicrotasks();
      verify(() => priceCall('USD')).called(1);
      verify(() => priceCall('CAD')).called(1);
    });
  });

  test('a failed fetch is not kept: the next read asks again', () {
    inFakeTime((time, repository, _, _) {
      // The datasource reports an unreachable pricer as a zero rate.
      when(() => priceCall('USD')).thenAnswer((_) async => 0);
      expect(read(time, repository), 0);
      when(() => priceCall('USD')).thenAnswer((_) async => 70000);
      expect(read(time, repository), 70000);
      verify(() => priceCall('USD')).called(2);
    });
  });

  test('a lapsed price is never served when the pricer fails', () {
    inFakeTime((time, repository, _, _) {
      read(time, repository);
      when(() => priceCall('USD')).thenAnswer((_) async => 0);
      time.elapse(const Duration(seconds: 61));
      expect(read(time, repository), 0, reason: 'not the minute-old 70000');
    });
  });

  test('a pricer silent for ten seconds fails the read', () {
    inFakeTime((time, repository, _, _) {
      when(
        () => priceCall('USD'),
      ).thenAnswer((_) => Completer<double>().future);
      double? value;
      repository
          .getCurrencyValue(amountSat: oneBtc, currency: 'USD')
          .then((v) => value = v);
      time.elapse(const Duration(seconds: 9, milliseconds: 999));
      expect(value, isNull);
      time.elapse(const Duration(milliseconds: 1));
      expect(value, 0);

      when(() => priceCall('USD')).thenAnswer((_) async => 70000);
      expect(read(time, repository), 70000);
      verify(() => priceCall('USD')).called(2);
    });
  });

  test('setting the device clock back does not keep a price fresh', () {
    inFakeTime((time, repository, shiftWallClock, _) {
      read(time, repository);
      time.elapse(const Duration(seconds: 30));
      shiftWallClock(const Duration(hours: -1));
      read(time, repository);
      verify(() => priceCall('USD')).called(2);
    });
  });

  test('a small step back of the clock still expires the price on time', () {
    inFakeTime((time, repository, shiftWallClock, _) {
      read(time, repository);
      time.elapse(const Duration(seconds: 50));
      // The wall age drops to 30 s; the monotonic age keeps counting.
      shiftWallClock(const Duration(seconds: -20));
      time.elapse(const Duration(seconds: 10));
      read(time, repository);
      verify(() => priceCall('USD')).called(2);
    });
  });

  test('time asleep ages the price even if the monotonic clock missed it', () {
    inFakeTime((time, repository, _, sleep) {
      read(time, repository);
      sleep(const Duration(minutes: 10));
      read(time, repository);
      verify(() => priceCall('USD')).called(2);
    });
  });
  test('tells when the price it serves was fetched', () {
    inFakeTime((time, repository, _, _) {
      expect(repository.priceFetchedAt('USD'), isNull);
      read(time, repository);
      final fetchedAt = clock.now();
      time.elapse(const Duration(seconds: 30));
      read(time, repository);
      expect(repository.priceFetchedAt('usd'), fetchedAt);
    });
  });
}
