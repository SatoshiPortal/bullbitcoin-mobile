import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';

class GetAvailableCurrenciesUsecase {
  final ExchangeRateRepository _exchangeRate;

  GetAvailableCurrenciesUsecase({
    required ExchangeRateRepository exchangeRateRepository,
  }) : _exchangeRate = exchangeRateRepository;

  Future<List<String>> execute() async {
    try {
      final currencies = await _exchangeRate.availableCurrencies;

      return currencies;
    } catch (e) {
      throw CurrenciesException('$e');
    }
  }
}

class CurrenciesException implements Exception {
  final String message;

  CurrenciesException(this.message);
}
