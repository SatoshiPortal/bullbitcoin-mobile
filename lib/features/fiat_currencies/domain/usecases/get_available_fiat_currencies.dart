import 'package:bb_mobile/features/fiat_currencies/domain/repositories/fiat_currencies_repository.dart';

class GetAvailableFiatCurrenciesUseCase {
  final FiatCurrenciesRepository _fiatCurrenciesRepository;

  GetAvailableFiatCurrenciesUseCase({
    required FiatCurrenciesRepository fiatCurrenciesRepository,
  }) : _fiatCurrenciesRepository = fiatCurrenciesRepository;

  Future<List<String>> execute() async {
    final currencies = await _fiatCurrenciesRepository.getAvailableCurrencies();

    return currencies;
  }
}
