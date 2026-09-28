import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/price/domain/repositories/bitcoin_price_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class GetAvailableCurrenciesUsecase {
  final BitcoinPriceRepository _mainnetBitcoinPriceRepository;
  final BitcoinPriceRepository _testnetBitcoinPriceRepository;
  final SettingsRepository _settingsRepository;

  GetAvailableCurrenciesUsecase({
    required this._mainnetBitcoinPriceRepository,
    required this._testnetBitcoinPriceRepository,
    required this._settingsRepository,
  });

  Future<List<String>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetBitcoinPriceRepository
          : _mainnetBitcoinPriceRepository;
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
