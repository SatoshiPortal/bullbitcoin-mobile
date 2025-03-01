import 'package:bb_mobile/fiat_currencies/domain/repositories/fiat_currencies_repository.dart';
import 'package:decimal/decimal.dart';

class FetchBitcoinPriceUseCase {
  final FiatCurrenciesRepository _fiatCurrenciesRepository;

  FetchBitcoinPriceUseCase({
    required FiatCurrenciesRepository fiatCurrenciesRepository,
  }) : _fiatCurrenciesRepository = fiatCurrenciesRepository;

  Future<Decimal> execute(String currencyCode) async {
    final price = await _fiatCurrenciesRepository.getBitcoinPrice(currencyCode);

    return price;
  }
}
