import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/local_rate_history_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/rate_history_model.dart';
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
    required String interval,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final latestDate = await _localRateHistory.getLatestRateDate(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        interval: interval,
      );

      DateTime? apiFromDate;
      if (latestDate == null) {
        apiFromDate =
            fromDate ?? DateTime.now().subtract(const Duration(days: 365));
      } else {
        final nextDate = switch (interval) {
          'hour' => latestDate.add(const Duration(hours: 1)),
          'day' => latestDate.add(const Duration(days: 1)),
          'week' => latestDate.add(const Duration(days: 7)),
          _ => latestDate.add(const Duration(days: 1)),
        };
        apiFromDate = nextDate;
      }

      final apiToDate = toDate ?? DateTime.now();

      if (apiFromDate.isBefore(apiToDate)) {
        try {
          final apiDatasource = _bitcoinPrice as BullbitcoinApiDatasource;
          final apiResponse = await apiDatasource.getIndexRateHistory(
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            interval: interval,
            fromDate: apiFromDate,
            toDate: apiToDate,
          );

          if (apiResponse.rates != null && apiResponse.rates!.isNotEmpty) {
            await _localRateHistory.storeRates(
              rates: apiResponse.rates!,
              fromCurrency: fromCurrency,
              toCurrency: toCurrency,
              interval: interval,
            );
          }
        } catch (e) {
          log.warning('Failed to fetch rate history from API: $e');
        }
      }

      // Cleanup old rates based on interval-specific retention periods
      final maxAge = switch (interval) {
        'hour' => const Duration(days: 1), // 1 day for hourly
        'day' => const Duration(days: 30), // 1 month for daily
        'week' => const Duration(days: 365), // 1 year for weekly
        _ => const Duration(days: 365), // Default to 1 year
      };
      
      await _localRateHistory.cleanupOldRates(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        interval: interval,
        maxAge: maxAge,
      );

      final localRates = await _localRateHistory.getRates(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        interval: interval,
        fromDate: fromDate,
        toDate: toDate,
      );

      if (localRates.isEmpty) {
        return RateHistory(
          fromCurrency: FiatCurrency.fromCode(fromCurrency),
          toCurrency: toCurrency,
          interval: RateTimelineInterval.fromString(interval),
          rates: [],
        );
      }

      final firstRate = localRates.first;
      final rateHistory = RateHistoryModel(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        precision: firstRate.precision,
        interval: interval,
        rates: localRates,
      );

      return rateHistory.toEntity();
    } catch (e) {
      log.warning('getIndexRateHistory error: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, RateHistory>> getAllIntervalsRateHistory({
    required String fromCurrency,
    required String toCurrency,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final intervals = ['hour', 'day', 'week'];

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

    final map = <String, RateHistory>{};
    for (var i = 0; i < intervals.length; i++) {
      map[intervals[i]] = results[i];
    }

    return map;
  }
}
