import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class ConvertCurrencyToSatsAmountUsecase {
  final ExchangeRateRepository _exchangeRate;
  final SettingsRepository _settingsRepository;

  ConvertCurrencyToSatsAmountUsecase({
    required ExchangeRateRepository exchangeRateRepository,
    required SettingsRepository settingsRepository,
  })  : _exchangeRate = exchangeRateRepository,
        _settingsRepository = settingsRepository;

  Future<BigInt> execute({
    required double amountFiat,
    String? currencyCode,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final currency = settings.currencyCode;
      final availableCurrencies = await _exchangeRate.availableCurrencies;

      if (!availableCurrencies.contains(currency)) {
        throw ConvertCurrencyToSatsAmountException('Currency not available');
      }

      return _exchangeRate.getSatsValue(
        amountFiat: amountFiat,
        currency: currency,
      );
    } catch (e) {
      throw ConvertCurrencyToSatsAmountException('$e');
    }
  }
}

class ConvertCurrencyToSatsAmountException implements Exception {
  final String message;

  ConvertCurrencyToSatsAmountException(this.message);
}
