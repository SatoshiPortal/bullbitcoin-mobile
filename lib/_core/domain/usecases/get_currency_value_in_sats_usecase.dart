import 'package:bb_mobile/_core/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';

class GetCurrencyValueInSatsUsecase {
  final ExchangeRateRepository _exchangeRate;
  final SettingsRepository _settingsRepository;

  GetCurrencyValueInSatsUsecase(
      {required ExchangeRateRepository exchangeRateRepository,
      required SettingsRepository settingsRepository})
      : _exchangeRate = exchangeRateRepository,
        _settingsRepository = settingsRepository;

  Future<BigInt> execute({
    required double amountFiat,
    String? currencyCode,
  }) async {
    try {
      final currency = currencyCode ?? await _settingsRepository.getCurrency();
      final availableCurrencies = await _exchangeRate.availableCurrencies;

      if (!availableCurrencies.contains(currency)) {
        throw SatsValueException('Currency not available');
      }

      return _exchangeRate.getSatsValue(
        amountFiat: amountFiat,
        currency: currency,
      );
    } catch (e) {
      throw SatsValueException('$e');
    }
  }
}

class SatsValueException implements Exception {
  final String message;

  SatsValueException(this.message);
}
