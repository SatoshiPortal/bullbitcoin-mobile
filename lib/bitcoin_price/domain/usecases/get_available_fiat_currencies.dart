import 'package:bb_mobile/bitcoin_price/domain/repositories/bitcoin_price_repository.dart';

class GetAvailableFiatCurrenciesUseCase {
  final BitcoinPriceRepository _bitcoinPriceRepository;

  GetAvailableFiatCurrenciesUseCase({
    required BitcoinPriceRepository bitcoinPriceRepository,
  }) : _bitcoinPriceRepository = bitcoinPriceRepository;

  Future<List<String>> execute() async {
    final currencies = await _bitcoinPriceRepository.getAvailableCurrencies();

    return currencies;
  }
}
