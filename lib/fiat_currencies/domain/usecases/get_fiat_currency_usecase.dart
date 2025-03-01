import 'package:bb_mobile/fiat_currencies/domain/repositories/fiat_currencies_repository.dart';

class GetFiatCurrencyUseCase {
  final FiatCurrenciesRepository _fiatCurrenciesRepository;

  GetFiatCurrencyUseCase({
    required FiatCurrenciesRepository fiatCurrenciesRepository,
  }) : _fiatCurrenciesRepository = fiatCurrenciesRepository;

  Future<String> execute() async {
    final currencyCode = await _fiatCurrenciesRepository.getCurrency();

    return currencyCode;
  }
}
