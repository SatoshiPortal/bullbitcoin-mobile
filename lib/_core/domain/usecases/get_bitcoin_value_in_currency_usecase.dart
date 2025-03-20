import 'package:bb_mobile/_core/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_utils/constants.dart';

class GetBitcoinValueInCurrencyUsecase {
  final ExchangeRateRepository _exchangeRate;
  final SettingsRepository _settingsRepository;

  GetBitcoinValueInCurrencyUsecase({
    required ExchangeRateRepository exchangeRateRepository,
    required SettingsRepository settingsRepository,
  })  : _exchangeRate = exchangeRateRepository,
        _settingsRepository = settingsRepository;

  Future<double> execute({
    BigInt? amountSat,
    String? currencyCode,
  }) async {
    try {
      final currency = currencyCode ?? await _settingsRepository.getCurrency();
      final availableCurrencies = await _exchangeRate.availableCurrencies;

      if (!availableCurrencies.contains(currency)) {
        throw CurrencyValueException('Currency not available');
      }

      return _exchangeRate.getCurrencyValue(
        amountSat: amountSat ?? ConversionConstants.satsAmountOfOneBitcoin,
        currency: currency,
      );
    } catch (e) {
      throw CurrencyValueException('$e');
    }
  }
}

class CurrencyValueException implements Exception {
  final String message;

  CurrencyValueException(this.message);
}
