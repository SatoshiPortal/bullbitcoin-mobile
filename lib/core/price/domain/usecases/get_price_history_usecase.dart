import 'package:bb_mobile/core/price/domain/rate.dart';
import 'package:bb_mobile/core/price/domain/repositories/price_history_repository.dart';

class GetPriceHistoryUsecase {
  final PriceHistoryRepository _priceHistoryRepository;

  GetPriceHistoryUsecase({required this._priceHistoryRepository});

  Future<List<Rate>> execute({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return await _priceHistoryRepository.getPriceHistory(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      interval: interval,
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}
