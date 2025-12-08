import 'package:bb_mobile/core/exchange/domain/entity/rate.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/price_repository.dart';

class RefreshPriceHistoryUsecase {
  final PriceRepository _priceRepository;

  RefreshPriceHistoryUsecase({required PriceRepository priceRepository})
    : _priceRepository = priceRepository;

  Future<List<Rate>> execute({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return await _priceRepository.refreshPriceHistory(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      interval: interval,
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}
