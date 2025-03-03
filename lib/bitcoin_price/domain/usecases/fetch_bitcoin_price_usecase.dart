import 'package:bb_mobile/bitcoin_price/domain/repositories/bitcoin_price_repository.dart';
import 'package:decimal/decimal.dart';

class FetchBitcoinPriceUseCase {
  final BitcoinPriceRepository _bitcoinPriceRepository;

  FetchBitcoinPriceUseCase({
    required BitcoinPriceRepository bitcoinPriceRepository,
  }) : _bitcoinPriceRepository = bitcoinPriceRepository;

  Future<Decimal> execute(String currencyCode) async {
    final price = await _bitcoinPriceRepository.getBitcoinPrice(currencyCode);

    return price;
  }
}
