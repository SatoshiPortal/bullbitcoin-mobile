import 'package:bb_mobile/core_deprecated/exchange/domain/entity/rate.dart';

abstract class PriceRepository {
  Future<List<Rate>> getPriceHistory({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<List<Rate>> refreshPriceHistory({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<void> savePriceHistory(List<Rate> prices);
}
