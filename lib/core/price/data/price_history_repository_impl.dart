import 'package:bb_mobile/core/price/data/datasources/local_price_history_datasource.dart';
import 'package:bb_mobile/core/price/data/datasources/bullbitcoin_price_datasource.dart';
import 'package:bb_mobile/core/price/domain/rate.dart';
import 'package:bb_mobile/core/price/domain/repositories/price_history_repository.dart';

class PriceHistoryRepositoryImpl implements PriceHistoryRepository {
  final BullbitcoinPriceDatasource _bullbitcoinPriceDatasource;
  final LocalPriceHistoryDatasource _localPriceHistoryDatasource;

  PriceHistoryRepositoryImpl({
    required this._bullbitcoinPriceDatasource,
    required this._localPriceHistoryDatasource,
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

    final localPrices = await _localPriceHistoryDatasource.getPriceHistory(
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

    final remotePriceModels = await _bullbitcoinPriceDatasource.getPriceHistory(
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

      await _localPriceHistoryDatasource.clearPrices(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        interval: interval.value,
      );

      await _localPriceHistoryDatasource.savePrices(remotePrices);

      if (interval == RateTimelineInterval.fifteen) {
        final dayFromDate = now.subtract(const Duration(days: 90));
        final localDay = await _localPriceHistoryDatasource.getPriceHistory(
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          interval: RateTimelineInterval.day,
          fromDate: dayFromDate,
          toDate: now,
        );

        if (localDay.isEmpty) {
          final dayPrices = await _bullbitcoinPriceDatasource.getPriceHistory(
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
            await _localPriceHistoryDatasource.clearPrices(
              fromCurrency: fromCurrency,
              toCurrency: toCurrency,
              interval: RateTimelineInterval.day.value,
            );
            await _localPriceHistoryDatasource.savePrices(dayPricesEntities);
            await _localPriceHistoryDatasource.cleanupOldRates(
              fromCurrency: fromCurrency,
              toCurrency: toCurrency,
              interval: RateTimelineInterval.day.value,
              maxAge: const Duration(days: 90),
            );
          }
        }

        await _localPriceHistoryDatasource.cleanupOldRates(
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          interval: RateTimelineInterval.fifteen.value,
          maxAge: const Duration(minutes: 15),
        );
      } else if (interval == RateTimelineInterval.day) {
        await _localPriceHistoryDatasource.cleanupOldRates(
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          interval: RateTimelineInterval.day.value,
          maxAge: const Duration(days: 90),
        );

        final fifteenFromDate = now.subtract(const Duration(minutes: 15));
        final localFifteen = await _localPriceHistoryDatasource.getPriceHistory(
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          interval: RateTimelineInterval.fifteen,
          fromDate: fifteenFromDate,
          toDate: now,
        );

        if (localFifteen.isEmpty) {
          final fifteenPrices = await _bullbitcoinPriceDatasource
              .getPriceHistory(
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
            await _localPriceHistoryDatasource.clearPrices(
              fromCurrency: fromCurrency,
              toCurrency: toCurrency,
              interval: RateTimelineInterval.fifteen.value,
            );
            await _localPriceHistoryDatasource.savePrices(
              fifteenPricesEntities,
            );
            await _localPriceHistoryDatasource.cleanupOldRates(
              fromCurrency: fromCurrency,
              toCurrency: toCurrency,
              interval: RateTimelineInterval.fifteen.value,
              maxAge: const Duration(minutes: 15),
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
    await _localPriceHistoryDatasource.savePrices(prices);
  }
}
