import 'package:bb_mobile/core_deprecated/exchange/data/datasources/price_local_datasource.dart';
import 'package:bb_mobile/core_deprecated/exchange/data/datasources/price_remote_datasource.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/entity/rate.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/repositories/price_repository.dart';

class PriceRepositoryImpl implements PriceRepository {
  final PriceRemoteDatasource _remoteDatasource;
  final PriceLocalDatasource _localDatasource;

  PriceRepositoryImpl({
    required PriceRemoteDatasource remoteDatasource,
    required PriceLocalDatasource localDatasource,
  }) : _remoteDatasource = remoteDatasource,
       _localDatasource = localDatasource;

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

      await _localDatasource.clearPrices(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        interval: interval.value,
      );

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
            await _localDatasource.clearPrices(
              fromCurrency: fromCurrency,
              toCurrency: toCurrency,
              interval: RateTimelineInterval.day.value,
            );
            await _localDatasource.savePrices(dayPricesEntities);
            await _localDatasource.cleanupOldRates(
              fromCurrency: fromCurrency,
              toCurrency: toCurrency,
              interval: RateTimelineInterval.day.value,
              maxAge: const Duration(days: 90),
            );
          }
        }

        await _localDatasource.cleanupOldRates(
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          interval: RateTimelineInterval.fifteen.value,
          maxAge: const Duration(minutes: 15),
        );
      } else if (interval == RateTimelineInterval.day) {
        await _localDatasource.cleanupOldRates(
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          interval: RateTimelineInterval.day.value,
          maxAge: const Duration(days: 90),
        );

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
            await _localDatasource.clearPrices(
              fromCurrency: fromCurrency,
              toCurrency: toCurrency,
              interval: RateTimelineInterval.fifteen.value,
            );
            await _localDatasource.savePrices(fifteenPricesEntities);
            await _localDatasource.cleanupOldRates(
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
    await _localDatasource.savePrices(prices);
  }
}
