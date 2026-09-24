import 'package:bb_mobile/core/price/domain/rate.dart';
import 'package:bb_mobile/core/price/domain/repositories/price_history_repository.dart';

// NOTE: not used anywhere as of now
class SavePriceHistoryUsecase {
  final PriceHistoryRepository _priceHistoryRepository;

  SavePriceHistoryUsecase({required this._priceHistoryRepository});

  Future<void> execute(List<Rate> prices) async {
    await _priceHistoryRepository.savePriceHistory(prices);
  }
}
