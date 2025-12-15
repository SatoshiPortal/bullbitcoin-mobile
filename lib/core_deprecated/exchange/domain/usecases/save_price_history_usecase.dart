import 'package:bb_mobile/core_deprecated/exchange/domain/entity/rate.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/repositories/price_repository.dart';

class SavePriceHistoryUsecase {
  final PriceRepository _priceRepository;

  SavePriceHistoryUsecase({required PriceRepository priceRepository})
    : _priceRepository = priceRepository;

  Future<void> execute(List<Rate> prices) async {
    await _priceRepository.savePriceHistory(prices);
  }
}
