import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';

class ConvertSatsToCurrencyAmountUsecase {
  final ExchangeRateRepository _mainnetExchangeRateRepository;
  final ExchangeRateRepository _testnetExchangeRateRepository;
  final SettingsRepository _settingsRepository;

  ConvertSatsToCurrencyAmountUsecase({
    required ExchangeRateRepository mainnetExchangeRateRepository,
    required ExchangeRateRepository testnetExchangeRateRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeRateRepository = mainnetExchangeRateRepository,
       _testnetExchangeRateRepository = testnetExchangeRateRepository,
       _settingsRepository = settingsRepository;

  Future<double> execute({BigInt? amountSat, String? currencyCode}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final currency = currencyCode ?? settings.currencyCode;
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeRateRepository
              : _mainnetExchangeRateRepository;
      final availableCurrencies = await repo.availableCurrencies;

      if (!availableCurrencies.contains(currency)) {
        throw ConvertSatsToCurrencyAmountException('Currency not available');
      }

      // If no amount is specified, return the price of one Bitcoin
      return repo.getCurrencyValue(
        amountSat: amountSat ?? ConversionConstants.satsAmountOfOneBitcoin,
        currency: currency,
      );
    } catch (e) {
      throw ConvertSatsToCurrencyAmountException(e.toString());
    }
  }
}

class ConvertSatsToCurrencyAmountException extends BullException {
  ConvertSatsToCurrencyAmountException(super.message);
}
