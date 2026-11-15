import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The price of one bitcoin in [currencyCode], on the network of the settings.
class GetBitcoinPriceUsecase {
  final GetSettingsUsecase _getSettingsUsecase;
  final IndexPriceReader _getIndexPrice;

  const GetBitcoinPriceUsecase({
    required this._getSettingsUsecase,
    required this._getIndexPrice,
  });

  @useResult
  Future<Result<double, PricerFailure>> execute({
    required String currencyCode,
  }) async {
    final SettingsEntity settings;
    try {
      settings = await _getSettingsUsecase.execute();
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the settings for the bitcoin price',
        error: e,
        trace: st,
      );
      return Err(PricerUnexpectedFailure('$e'));
    }
    final currency = SupportedCurrency.tryFromCode(currencyCode);
    if (currency == null) {
      return Err(
        PricerUnexpectedFailure('Currency not available: $currencyCode'),
      );
    }
    final price = await _getIndexPrice(
      network: switch (settings.environment) {
        Environment.mainnet => BitcoinNetwork.mainnet,
        Environment.testnet => BitcoinNetwork.testnet,
        Environment.regtest => BitcoinNetwork.regtest,
      },
      currency: currency,
    );
    if (price case Err(:final failure)) {
      log.warning('Bitcoin price unavailable: ${failure.runtimeType}');
    }
    return price.map((value) => value.fiatAmount);
  }
}
