import 'package:bb_mobile/core/exchange/data/datasources/price_local_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/price_remote_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/rate_model.dart';
import 'package:bb_mobile/core/exchange/data/repository/price_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/entity/rate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements PriceRemoteDatasource {}

class _MockLocal extends Mock implements PriceLocalDatasource {}

RateModel _model(String iso) => RateModel(
  fromCurrency: 'BTC',
  toCurrency: 'USD',
  interval: 'day',
  createdAt: iso,
  marketPrice: null,
  price: null,
  priceCurrency: null,
  precision: 2,
  indexPrice: 100000,
  userPrice: null,
);

void main() {
  late _MockRemote remote;
  late _MockLocal local;
  late PriceRepositoryImpl repo;

  setUpAll(() {
    registerFallbackValue(<Rate>[]);
    registerFallbackValue(RateTimelineInterval.day);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    remote = _MockRemote();
    local = _MockLocal();
    repo = PriceRepositoryImpl(
      remoteDatasource: remote,
      localDatasource: local,
    );

    when(() => local.savePrices(any())).thenAnswer((_) async {});
    when(
      () => local.cleanupOldRates(
        fromCurrency: any(named: 'fromCurrency'),
        toCurrency: any(named: 'toCurrency'),
        interval: any(named: 'interval'),
        maxAge: any(named: 'maxAge'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => local.clearPrices(
        fromCurrency: any(named: 'fromCurrency'),
        toCurrency: any(named: 'toCurrency'),
        interval: any(named: 'interval'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => local.getPriceHistory(
        fromCurrency: any(named: 'fromCurrency'),
        toCurrency: any(named: 'toCurrency'),
        interval: any(named: 'interval'),
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'),
      ),
    ).thenAnswer((_) async => <Rate>[]);
  });

  group('refreshPriceHistory keeps the backfilled history', () {
    test('never clears stored prices before saving', () async {
      when(
        () => remote.getPriceHistory(
          fromCurrency: any(named: 'fromCurrency'),
          toCurrency: any(named: 'toCurrency'),
          interval: any(named: 'interval'),
          fromDate: any(named: 'fromDate'),
          toDate: any(named: 'toDate'),
        ),
      ).thenAnswer((_) async => [_model('2026-09-01T00:00:00.000Z')]);

      await repo.refreshPriceHistory(
        fromCurrency: 'BTC',
        toCurrency: 'USD',
        interval: RateTimelineInterval.day,
      );

      // savePrices upserts on {fromCurrency, toCurrency, interval, createdAt},
      // so a refresh merges. Clearing first would delete every backfilled row
      // the transaction history depends on.
      verifyNever(
        () => local.clearPrices(
          fromCurrency: any(named: 'fromCurrency'),
          toCurrency: any(named: 'toCurrency'),
          interval: any(named: 'interval'),
        ),
      );
      verify(() => local.savePrices(any())).called(greaterThanOrEqualTo(1));
    });

    test('never sweeps day rows', () async {
      when(
        () => remote.getPriceHistory(
          fromCurrency: any(named: 'fromCurrency'),
          toCurrency: any(named: 'toCurrency'),
          interval: any(named: 'interval'),
          fromDate: any(named: 'fromDate'),
          toDate: any(named: 'toDate'),
        ),
      ).thenAnswer((_) async => [_model('2026-09-01T00:00:00.000Z')]);

      await repo.refreshPriceHistory(
        fromCurrency: 'BTC',
        toCurrency: 'USD',
        interval: RateTimelineInterval.day,
      );

      // Day rows are the only thing that can price a years-old transaction.
      verifyNever(
        () => local.cleanupOldRates(
          fromCurrency: any(named: 'fromCurrency'),
          toCurrency: any(named: 'toCurrency'),
          interval: RateTimelineInterval.day.value,
          maxAge: any(named: 'maxAge'),
        ),
      );
    });

    test('keeps fifteen rows for 90 days, not 15 minutes', () async {
      when(
        () => remote.getPriceHistory(
          fromCurrency: any(named: 'fromCurrency'),
          toCurrency: any(named: 'toCurrency'),
          interval: any(named: 'interval'),
          fromDate: any(named: 'fromDate'),
          toDate: any(named: 'toDate'),
        ),
      ).thenAnswer((_) async => [_model('2026-09-01T00:00:00.000Z')]);

      await repo.refreshPriceHistory(
        fromCurrency: 'BTC',
        toCurrency: 'USD',
        interval: RateTimelineInterval.fifteen,
      );

      final captured = verify(
        () => local.cleanupOldRates(
          fromCurrency: any(named: 'fromCurrency'),
          toCurrency: any(named: 'toCurrency'),
          interval: RateTimelineInterval.fifteen.value,
          maxAge: captureAny(named: 'maxAge'),
        ),
      ).captured;

      expect(captured, isNotEmpty);
      expect(captured.first, const Duration(days: 90));
      expect(captured.first, isNot(const Duration(minutes: 15)));
    });
  });

  group('the price chart read windows are unchanged', () {
    test('day reads the trailing 90 days', () async {
      final before = DateTime.now().toUtc();
      await repo.getPriceHistory(
        fromCurrency: 'BTC',
        toCurrency: 'USD',
        interval: RateTimelineInterval.day,
      );

      final from =
          verify(
                () => local.getPriceHistory(
                  fromCurrency: any(named: 'fromCurrency'),
                  toCurrency: any(named: 'toCurrency'),
                  interval: RateTimelineInterval.day,
                  fromDate: captureAny(named: 'fromDate'),
                  toDate: any(named: 'toDate'),
                ),
              ).captured.first
              as DateTime;

      final window = before.difference(from);
      expect(window.inDays, closeTo(90, 1));
    });

    test('fifteen still reads only the trailing 15 minutes', () async {
      final before = DateTime.now().toUtc();
      await repo.getPriceHistory(
        fromCurrency: 'BTC',
        toCurrency: 'USD',
        interval: RateTimelineInterval.fifteen,
      );

      final from =
          verify(
                () => local.getPriceHistory(
                  fromCurrency: any(named: 'fromCurrency'),
                  toCurrency: any(named: 'toCurrency'),
                  interval: RateTimelineInterval.fifteen,
                  fromDate: captureAny(named: 'fromDate'),
                  toDate: any(named: 'toDate'),
                ),
              ).captured.first
              as DateTime;

      // Storing 90 days of fifteen rows must not widen what the chart reads.
      // The read window bounds the chart, not the table size.
      final window = before.difference(from);
      expect(window.inMinutes, closeTo(15, 1));
    });
  });
}
