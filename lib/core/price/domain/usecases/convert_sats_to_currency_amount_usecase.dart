import 'package:bb_mobile/core/price/domain/repositories/bitcoin_price_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class ConvertSatsToCurrencyAmountUsecase {
  final BitcoinPriceRepository _mainnetBitcoinPriceRepository;
  final BitcoinPriceRepository _testnetBitcoinPriceRepository;
  final SettingsRepository _settingsRepository;

  ConvertSatsToCurrencyAmountUsecase({
    required this._mainnetBitcoinPriceRepository,
    required this._testnetBitcoinPriceRepository,
    required this._settingsRepository,
  });

  /// [amountSat] in [currencyCode], or the settings currency when none is
  /// given. Without an amount, the price of one bitcoin.
  @useResult
  Future<Result<double, PricerFailure>> execute({
    BigInt? amountSat,
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
    return repo.getCurrencyValue(
      amountSat: amountSat ?? ConversionConstants.satsAmountOfOneBitcoin,
      currency: currencyCode ?? settings.currencyCode,
    );
  }
}
