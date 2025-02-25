import 'package:bb_mobile/features/fiat_currencies/domain/repositories/fiat_currencies_repository.dart';

class SetFiatCurrencyUseCase {
  final FiatCurrenciesRepository _fiatCurrenciesRepository;

  SetFiatCurrencyUseCase({
    required FiatCurrenciesRepository fiatCurrenciesRepository,
  }) : _fiatCurrenciesRepository = fiatCurrenciesRepository;

  Future<void> execute(String currencyCode) async {
    await _fiatCurrenciesRepository.setCurrency(currencyCode);
  }
}
