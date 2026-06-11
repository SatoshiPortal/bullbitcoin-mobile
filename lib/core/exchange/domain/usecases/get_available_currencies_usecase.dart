import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class GetAvailableCurrenciesUsecase {
  final ExchangeRateRepository _mainnetExchangeRateRepository;
  final ExchangeRateRepository _testnetExchangeRateRepository;
  final SettingsRepository _settingsRepository;

  GetAvailableCurrenciesUsecase({
    required this._mainnetExchangeRateRepository,
    required this._testnetExchangeRateRepository,
    required this._settingsRepository,
  });

  Future<List<String>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeRateRepository
              : _mainnetExchangeRateRepository;
      final currencies = await repo.availableCurrencies;
      return currencies;
    } catch (e) {
      throw CurrenciesException('$e');
    }
  }
}

class CurrenciesException extends BullException {
  CurrenciesException(super.message);
}
