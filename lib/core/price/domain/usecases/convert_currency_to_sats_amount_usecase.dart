import 'package:bb_mobile/core/price/domain/repositories/bitcoin_price_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

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

  @useResult
  Future<Result<BigInt, PricerFailure>> execute({
    required double amountFiat,
    String? currencyCode,
  }) async {
    final SettingsEntity settings;
    try {
      settings = await _settingsRepository.fetch();
    } on Exception catch (e) {
      return Err(
        PricerUnexpectedFailure('Settings unavailable: ${e.runtimeType}'),
      );
    }
    final repo = settings.environment.isTestnet
        ? _testnetBitcoinPriceRepository
        : _mainnetBitcoinPriceRepository;
    return repo.getSatsValue(
      amountFiat: amountFiat,
      currency: settings.currencyCode,
    );
  }
}
