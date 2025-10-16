import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class ConvertCurrencyToSatsAmountUsecase {
  final ExchangeRateRepository _mainnetExchangeRateRepository;
  final ExchangeRateRepository _testnetExchangeRateRepository;
  final SettingsRepository _settingsRepository;

  ConvertCurrencyToSatsAmountUsecase({
    required ExchangeRateRepository mainnetExchangeRateRepository,
    required ExchangeRateRepository testnetExchangeRateRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeRateRepository = mainnetExchangeRateRepository,
       _testnetExchangeRateRepository = testnetExchangeRateRepository,
       _settingsRepository = settingsRepository;

  Future<BigInt> execute({
    required double amountFiat,
    String? currencyCode,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final currency = settings.currencyCode;
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeRateRepository
              : _mainnetExchangeRateRepository;
      final availableCurrencies = await repo.availableCurrencies;

      if (!availableCurrencies.contains(currency)) {
        throw ConvertCurrencyToSatsAmountException('Currency not available');
      }

      return repo.getSatsValue(amountFiat: amountFiat, currency: currency);
    } catch (e) {
      throw ConvertCurrencyToSatsAmountException(e.toString());
    }
  }
}

class ConvertCurrencyToSatsAmountException extends BullException {
  ConvertCurrencyToSatsAmountException(super.message);
}
