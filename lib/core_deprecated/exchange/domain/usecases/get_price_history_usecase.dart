import 'package:bb_mobile/core_deprecated/exchange/domain/entity/rate.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/repositories/price_repository.dart';

class GetPriceHistoryUsecase {
  final PriceRepository _priceRepository;

  GetPriceHistoryUsecase({required PriceRepository priceRepository})
    : _priceRepository = priceRepository;

  Future<List<Rate>> execute({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return await _priceRepository.getPriceHistory(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      interval: interval,
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}
