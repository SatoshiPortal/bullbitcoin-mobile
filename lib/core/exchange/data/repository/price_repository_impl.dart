import 'package:bb_mobile/core/exchange/data/datasources/price_local_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/price_remote_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/entity/rate.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/price_repository.dart';

class PriceRepositoryImpl implements PriceRepository {
  /// How long a `fifteen` row is kept.
  ///
  /// This was 15 minutes, which made the interval a spot-price cache rather
  /// than a history: every refresh deleted all but the newest row. The
  /// transaction history needs to price a payment received weeks ago to the
  /// quarter hour, so the rows are now kept for the same window the `day`
  /// tier serves the chart over. About 8,640 rows per currency.
  static const fifteenRetention = Duration(days: 90);

  /// `day` rows are never deleted.
  ///
  /// They previously expired after 90 days. They are now the only source that
  /// can price a transaction from years back, and the whole available history
  /// is about 1,223 rows per currency — the API returns nothing before
  /// 2023-03-15 — so the table is naturally bounded and needs no sweeping.

  final PriceRemoteDatasource _remoteDatasource;
  final PriceLocalDatasource _localDatasource;

  PriceRepositoryImpl({
    required this._remoteDatasource,
    required this._localDatasource,
  });

  @override
  Future<List<Rate>> getPriceHistory({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final now = toDate ?? DateTime.now().toUtc();

    DateTime? effectiveFromDate = fromDate;
    effectiveFromDate ??= switch (interval) {
      RateTimelineInterval.week => now.subtract(const Duration(days: 90)),
      RateTimelineInterval.fifteen => now.subtract(const Duration(minutes: 15)),
      RateTimelineInterval.hour => now.subtract(const Duration(days: 30)),
      RateTimelineInterval.day => now.subtract(const Duration(days: 90)),
    };

    final localPrices = await _localDatasource.getPriceHistory(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      interval: interval,
      fromDate: effectiveFromDate,
      toDate: now,
    );

    return localPrices;
  }

  @override
  Future<List<Rate>> refreshPriceHistory({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final now = toDate ?? DateTime.now().toUtc();

    DateTime? effectiveFromDate = fromDate;
    effectiveFromDate ??= switch (interval) {
      RateTimelineInterval.week => now.subtract(const Duration(days: 90)),
      RateTimelineInterval.fifteen => now.subtract(const Duration(minutes: 15)),
      RateTimelineInterval.hour => now.subtract(const Duration(days: 30)),
      RateTimelineInterval.day => now.subtract(const Duration(days: 90)),
    };

    final remotePriceModels = await _remoteDatasource.getPriceHistory(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      interval: interval,
      fromDate: effectiveFromDate,
      toDate: now,
    );

    if (remotePriceModels.isNotEmpty) {
      final remotePrices = remotePriceModels
          .map((model) => model.toEntity())
          .toList();

      await _localDatasource.savePrices(remotePrices);

      if (interval == RateTimelineInterval.fifteen) {
        final dayFromDate = now.subtract(const Duration(days: 90));
        final localDay = await _localDatasource.getPriceHistory(
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          interval: RateTimelineInterval.day,
          fromDate: dayFromDate,
          toDate: now,
        );

        if (localDay.isEmpty) {
          final dayPrices = await _remoteDatasource.getPriceHistory(
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            interval: RateTimelineInterval.day,
            fromDate: dayFromDate,
            toDate: now,
          );
          if (dayPrices.isNotEmpty) {
            final dayPricesEntities = dayPrices
                .map((model) => model.toEntity())
                .toList();
            await _localDatasource.savePrices(dayPricesEntities);
          }
        }

        await _localDatasource.cleanupOldRates(
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          interval: RateTimelineInterval.fifteen.value,
          maxAge: fifteenRetention,
        );
      } else if (interval == RateTimelineInterval.day) {
        final fifteenFromDate = now.subtract(const Duration(minutes: 15));
        final localFifteen = await _localDatasource.getPriceHistory(
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          interval: RateTimelineInterval.fifteen,
          fromDate: fifteenFromDate,
          toDate: now,
        );

        if (localFifteen.isEmpty) {
          final fifteenPrices = await _remoteDatasource.getPriceHistory(
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            interval: RateTimelineInterval.fifteen,
            fromDate: fifteenFromDate,
            toDate: now,
          );
          if (fifteenPrices.isNotEmpty) {
            final fifteenPricesEntities = fifteenPrices
                .map((model) => model.toEntity())
                .toList();
            await _localDatasource.savePrices(fifteenPricesEntities);
            await _localDatasource.cleanupOldRates(
              fromCurrency: fromCurrency,
              toCurrency: toCurrency,
              interval: RateTimelineInterval.fifteen.value,
              maxAge: fifteenRetention,
            );
          }
        }
      }

      return remotePrices;
    }

    return [];
  }

  @override
  Future<void> savePriceHistory(List<Rate> prices) async {
    await _localDatasource.savePrices(prices);
  }
}
