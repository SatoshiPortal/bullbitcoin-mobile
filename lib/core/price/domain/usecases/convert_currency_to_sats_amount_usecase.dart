import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/price/domain/repositories/bitcoin_price_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

// NOTE: not used anywhere as of now
class ConvertCurrencyToSatsAmountUsecase {
  final BitcoinPriceRepository _mainnetBitcoinPriceRepository;
  final BitcoinPriceRepository _testnetBitcoinPriceRepository;
  final SettingsRepository _settingsRepository;

  ConvertCurrencyToSatsAmountUsecase({
    required this._mainnetBitcoinPriceRepository,
    required this._testnetBitcoinPriceRepository,
    required this._settingsRepository,
  });

  Future<BigInt> execute({
    required double amountFiat,
    String? currencyCode,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final currency = settings.currencyCode;
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetBitcoinPriceRepository
          : _mainnetBitcoinPriceRepository;
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
