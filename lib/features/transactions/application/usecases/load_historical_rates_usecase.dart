import 'package:bb_mobile/core/exchange/domain/entity/historical_rate_series.dart';
import 'package:bb_mobile/core/exchange/domain/entity/rate.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_price_history_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/refresh_price_history_usecase.dart';
import 'package:bull_logger/bull_logger.dart';

/// Builds the rate series the transaction history prices its rows against.
class LoadHistoricalRatesUsecase {
  /// The earliest date the rate history holds anything.
  ///
  /// Measured against the live API: asking from epoch zero returns nothing
  /// before this. Some currencies start later still — MXN in August 2024,
  /// ARS in July 2025, COP in September 2025 — and the server simply omits
  /// the missing rows, so one floor for all currencies is safe.
  static final historyStart = DateTime.utc(2023, 3, 15);

  /// How far back quarter-hourly rates are held.
  static const fineWindow = Duration(days: 90);

  final GetPriceHistoryUsecase _getPriceHistory;
  final RefreshPriceHistoryUsecase _refreshPriceHistory;

  LoadHistoricalRatesUsecase({
    required GetPriceHistoryUsecase getPriceHistoryUsecase,
    required RefreshPriceHistoryUsecase refreshPriceHistoryUsecase,
  }) : _getPriceHistory = getPriceHistoryUsecase,
       _refreshPriceHistory = refreshPriceHistoryUsecase;

  /// Reads what is cached and returns it immediately.
  Future<HistoricalRateSeries> cached(String currencyCode) async {
    final now = DateTime.now().toUtc();
    final rates = await _readLocal(currencyCode, now);
    return HistoricalRateSeries.from(currency: currencyCode, rates: rates);
  }

  /// Pulls the full history from the network, then returns the merged series.
  ///
  /// **Always pulls wide.** The rate API caches on currency, interval and
  /// window *length*, ignoring the dates asked for, so several narrow requests
  /// of matching length return each other's data. A full-history pull has a
  /// distinctive length and cannot collide with the trailing windows the price
  /// chart requests.
  Future<HistoricalRateSeries> refresh(String currencyCode) async {
    final now = DateTime.now().toUtc();
    try {
      await _refreshPriceHistory.execute(
        fromCurrency: 'BTC',
        toCurrency: currencyCode,
        interval: RateTimelineInterval.day,
        fromDate: historyStart,
        toDate: now,
      );
      await _refreshPriceHistory.execute(
        fromCurrency: 'BTC',
        toCurrency: currencyCode,
        interval: RateTimelineInterval.fifteen,
        fromDate: now.subtract(fineWindow),
        toDate: now,
      );
    } catch (e) {
      // The cache keeps whatever it already had. A row that cannot be priced
      // shows nothing, which is the same as any other unknown rate.
      log.warning('Failed to refresh historical rates', error: e);
    }
    return cached(currencyCode);
  }

  Future<List<Rate>> _readLocal(String currencyCode, DateTime now) async {
    final results = await Future.wait([
      _getPriceHistory.execute(
        fromCurrency: 'BTC',
        toCurrency: currencyCode,
        interval: RateTimelineInterval.day,
        fromDate: historyStart,
        toDate: now,
      ),
      _getPriceHistory.execute(
        fromCurrency: 'BTC',
        toCurrency: currencyCode,
        interval: RateTimelineInterval.fifteen,
        fromDate: now.subtract(fineWindow),
        toDate: now,
      ),
    ]);
    return [...results[0], ...results[1]];
  }
}
