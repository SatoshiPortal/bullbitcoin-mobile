import 'package:bb_mobile/core/price/domain/rate.dart';
import 'package:bb_mobile/core/price/domain/repositories/price_history_repository.dart';

class RefreshPriceHistoryUsecase {
  final PriceHistoryRepository _priceHistoryRepository;

  RefreshPriceHistoryUsecase({required this._priceHistoryRepository});

  Future<List<Rate>> execute({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return await _priceHistoryRepository.refreshPriceHistory(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      interval: interval,
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}
