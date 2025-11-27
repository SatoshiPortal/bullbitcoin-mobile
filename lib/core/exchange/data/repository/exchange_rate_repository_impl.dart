import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/local_rate_history_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/rate_history_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/composite_rate_history.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/rate_history.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;

class ExchangeRateRepositoryImpl implements ExchangeRateRepository {
  final BitcoinPriceDatasource _bitcoinPrice;
  final LocalRateHistoryDatasource _localRateHistory;

  ExchangeRateRepositoryImpl({
    required BitcoinPriceDatasource bitcoinPriceDatasource,
    required LocalRateHistoryDatasource localRateHistoryDatasource,
  }) : _bitcoinPrice = bitcoinPriceDatasource,
       _localRateHistory = localRateHistoryDatasource;

  @override
  Future<List<String>> get availableCurrencies =>
      _bitcoinPrice.availableCurrencies;

  @override
  Future<double> getCurrencyValue({
    required BigInt amountSat,
    required String currency,
  }) async {
    final price = await _bitcoinPrice.getPrice(currency);
    final amountBtc = amountSat / BigInt.from(100000000);
    return amountBtc * price;
  }

  @override
  Future<BigInt> getSatsValue({
    required double amountFiat,
    required String currency,
  }) async {
    final price = await _bitcoinPrice.getPrice(currency);
    final amountBtc = amountFiat / price;
    return BigInt.from((amountBtc * 100000000).truncate());
  }

  @override
  Future<RateHistory> getIndexRateHistory({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final intervalString = interval.value;
      final localRates = await _localRateHistory.getRates(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        interval: intervalString,
        fromDate: fromDate,
        toDate: toDate,
      );

      if (localRates.isEmpty) {
        return RateHistory(
          fromCurrency: FiatCurrency.fromCode(fromCurrency),
          toCurrency: toCurrency,
          interval: interval,
          rates: [],
        );
      }

      final firstRate = localRates.first;
      final rateHistory = RateHistoryModel(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        precision: firstRate.precision,
        interval: intervalString,
        rates: localRates,
      );

      return rateHistory.toEntity();
    } catch (e) {
      log.warning('getIndexRateHistory error: $e');
      rethrow;
    }
  }

  @override
  Future<void> refreshAllRateHistory({
    required String fromCurrency,
    required String toCurrency,
  }) async {
    try {
      final intervals = [
        RateTimelineInterval.fifteen,
        RateTimelineInterval.week,
      ];
      final now = DateTime.now().toUtc();

      final latestDateAcrossAllIntervals = await _localRateHistory
          .getLatestRateDateAcrossAllIntervals(
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
          );

      for (final interval in intervals) {
        try {
          DateTime apiFromDate;
          if (latestDateAcrossAllIntervals == null) {
            apiFromDate = switch (interval) {
              RateTimelineInterval.fifteen => now.subtract(
                const Duration(days: 1),
              ),
              RateTimelineInterval.week => now.subtract(
                const Duration(days: 365 * 4),
              ),
              RateTimelineInterval.hour =>
                throw UnimplementedError('Hour interval not supported'),
              RateTimelineInterval.day =>
                throw UnimplementedError('Day interval not supported'),
            };
          } else {
            final nextDate = switch (interval) {
              RateTimelineInterval.fifteen => latestDateAcrossAllIntervals.add(
                const Duration(minutes: 15),
              ),
              RateTimelineInterval.week => latestDateAcrossAllIntervals.add(
                const Duration(days: 7),
              ),
              RateTimelineInterval.hour =>
                throw UnimplementedError('Hour interval not supported'),
              RateTimelineInterval.day =>
                throw UnimplementedError('Day interval not supported'),
            };
            apiFromDate = nextDate;
          }

          if (apiFromDate.isBefore(now)) {
            final apiDatasource = _bitcoinPrice as BullbitcoinApiDatasource;

            final cutoffDate = switch (interval) {
              RateTimelineInterval.fifteen => now.subtract(
                const Duration(minutes: 15),
              ),
              RateTimelineInterval.week => now.subtract(
                const Duration(days: 365 * 4),
              ),
              RateTimelineInterval.hour =>
                throw UnimplementedError('Hour interval not supported'),
              RateTimelineInterval.day =>
                throw UnimplementedError('Day interval not supported'),
            };

            final apiResponse = await apiDatasource.getIndexRateHistory(
              fromCurrency: fromCurrency,
              toCurrency: toCurrency,
              interval: interval.value,
              fromDate: apiFromDate,
              toDate: now,
            );

            if (apiResponse.rates != null && apiResponse.rates!.isNotEmpty) {
              await _localRateHistory.cleanupOldRates(
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                interval: interval.value,
                maxAge: now.difference(cutoffDate),
              );

              await _localRateHistory.storeRates(
                rates: apiResponse.rates!,
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                interval: interval.value,
              );

              final maxCount = switch (interval) {
                RateTimelineInterval.fifteen => 1,
                RateTimelineInterval.week => 52 * 4,
                RateTimelineInterval.hour =>
                  throw UnimplementedError('Hour interval not supported'),
                RateTimelineInterval.day =>
                  throw UnimplementedError('Day interval not supported'),
              };

              final allRates = await _localRateHistory.getRates(
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                interval: interval.value,
                fromDate: null,
                toDate: null,
              );

              if (allRates.length > maxCount) {
                allRates.sort((a, b) {
                  final dateA = DateTime.parse(a.createdAt!);
                  final dateB = DateTime.parse(b.createdAt!);
                  return dateB.compareTo(dateA);
                });

                final ratesToDelete = allRates.skip(maxCount);

                for (final rateToDelete in ratesToDelete) {
                  final createdAtStr = rateToDelete.createdAt;
                  if (createdAtStr != null) {
                    await _localRateHistory.deleteRateByDate(
                      fromCurrency: fromCurrency,
                      toCurrency: toCurrency,
                      interval: interval.value,
                      createdAt: createdAtStr,
                    );
                  }
                }
              }
            }
          }
        } catch (e) {
          log.warning(
            'Failed to refresh rate history for interval ${interval.value}: $e',
          );
        }
      }
    } catch (e) {
      log.warning('refreshAllRateHistory error: $e');
    }
  }

  @override
  Future<Map<RateTimelineInterval, RateHistory>> getAllIntervalsRateHistory({
    required String fromCurrency,
    required String toCurrency,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final intervals = [
      RateTimelineInterval.hour,
      RateTimelineInterval.day,
      RateTimelineInterval.week,
    ];

    final results = await Future.wait(
      intervals.map(
        (interval) => getIndexRateHistory(
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          interval: interval,
          fromDate: fromDate,
          toDate: toDate,
        ),
      ),
    );

    final map = <RateTimelineInterval, RateHistory>{};
    for (var i = 0; i < intervals.length; i++) {
      map[intervals[i]] = results[i];
    }

    return map;
  }

  @override
  Future<void> refreshRateHistory({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final intervalString = interval.value;
      final now = toDate ?? DateTime.now().toUtc();

      final latestDate = await _localRateHistory.getLatestRateDate(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        interval: intervalString,
      );

      final apiFromDate =
          fromDate ??
          latestDate?.add(switch (interval) {
            RateTimelineInterval.fifteen => const Duration(minutes: 15),
            RateTimelineInterval.hour => const Duration(hours: 1),
            RateTimelineInterval.day => const Duration(days: 1),
            RateTimelineInterval.week => const Duration(days: 7),
          }) ??
          switch (interval) {
            RateTimelineInterval.fifteen => now.subtract(
              const Duration(days: 1),
            ),
            RateTimelineInterval.hour => now.subtract(const Duration(days: 30)),
            RateTimelineInterval.day => now.subtract(const Duration(days: 30)),
            RateTimelineInterval.week => now.subtract(
              const Duration(days: 365 * 4),
            ),
          };

      if (apiFromDate.isBefore(now)) {
        final apiDatasource = _bitcoinPrice as BullbitcoinApiDatasource;
        final apiResponse = await apiDatasource.getIndexRateHistory(
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          interval: intervalString,
          fromDate: apiFromDate,
          toDate: now,
        );

        if (apiResponse.rates != null && apiResponse.rates!.isNotEmpty) {
          await _localRateHistory.storeRates(
            rates: apiResponse.rates!,
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            interval: intervalString,
          );
        }
      }
    } catch (e) {
      log.warning(
        'Failed to refresh rate history for interval ${interval.value}: $e',
      );
      rethrow;
    }
  }

  @override
  Future<CompositeRateHistory> getCompositeRateHistory({
    required String fromCurrency,
    required String toCurrency,
  }) async {
    try {
      final now = DateTime.now().toUtc();

      final fifteenFromDate = now.subtract(const Duration(minutes: 15));
      final weekFromDate = now.subtract(const Duration(days: 365 * 4));

      final fifteenRates = await _localRateHistory.getRates(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        interval: RateTimelineInterval.fifteen.value,
        fromDate: fifteenFromDate,
        toDate: now,
      );

      final weekRates = await _localRateHistory.getRates(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        interval: RateTimelineInterval.week.value,
        fromDate: weekFromDate,
        toDate: now,
      );

      final precision =
          fifteenRates.isNotEmpty
              ? fifteenRates.first.precision
              : weekRates.isNotEmpty
              ? weekRates.first.precision
              : 2;

      final latestRates =
          fifteenRates.isNotEmpty ? [fifteenRates.last.toEntity()] : <Rate>[];
      final yearsRateEntities = weekRates.map((r) => r.toEntity()).toList();

      final composite = CompositeRateHistory(
        latest: RateHistory(
          fromCurrency: FiatCurrency.fromCode(fromCurrency),
          toCurrency: toCurrency,
          precision: precision,
          interval: RateTimelineInterval.fifteen,
          rates: latestRates,
        ),
        day: RateHistory(
          fromCurrency: FiatCurrency.fromCode(fromCurrency),
          toCurrency: toCurrency,
          precision: precision,
          interval: RateTimelineInterval.hour,
          rates: <Rate>[],
        ),
        month: RateHistory(
          fromCurrency: FiatCurrency.fromCode(fromCurrency),
          toCurrency: toCurrency,
          precision: precision,
          interval: RateTimelineInterval.day,
          rates: <Rate>[],
        ),
        years: RateHistory(
          fromCurrency: FiatCurrency.fromCode(fromCurrency),
          toCurrency: toCurrency,
          precision: precision,
          interval: RateTimelineInterval.week,
          rates: yearsRateEntities,
        ),
      );

      return composite;
    } catch (e) {
      log.warning('getCompositeRateHistory error: $e');
      rethrow;
    }
  }
}
