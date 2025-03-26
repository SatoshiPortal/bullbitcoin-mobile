import 'package:bb_mobile/_core/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_utils/constants.dart';

class ConvertSatsToCurrencyAmountUsecase {
  final ExchangeRateRepository _exchangeRate;
  final SettingsRepository _settingsRepository;

  ConvertSatsToCurrencyAmountUsecase({
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
        throw ConvertSatsToCurrencyAmountException('Currency not available');
      }

      // If no amount is specified, return the price of one Bitcoin
      return _exchangeRate.getCurrencyValue(
        amountSat: amountSat ?? ConversionConstants.satsAmountOfOneBitcoin,
        currency: currency,
      );
    } catch (e) {
      throw ConvertSatsToCurrencyAmountException('$e');
    }
  }
}

class ConvertSatsToCurrencyAmountException implements Exception {
  final String message;

  ConvertSatsToCurrencyAmountException(this.message);
}
