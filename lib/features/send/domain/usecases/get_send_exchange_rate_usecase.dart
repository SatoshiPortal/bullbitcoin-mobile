import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:primitives/primitives.dart';

/// The price of one bitcoin in [currencyCode], or in the settings currency
/// when none is given, on the network of the settings. Null when there is
/// none: send shows no fiat value then.
class GetSendExchangeRateUsecase {
  final GetSettingsUsecase _getSettingsUsecase;
  final IndexPriceReader _getIndexPrice;

  const GetSendExchangeRateUsecase({
    required this._getSettingsUsecase,
    required this._getIndexPrice,
  });

  Future<double?> execute({String? currencyCode}) async {
    final SettingsEntity settings;
    try {
      settings = await _getSettingsUsecase.execute();
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the settings for the send price',
        error: e,
        trace: st,
      );
      return null;
    }
    final currency = SupportedCurrency.tryFromCode(
      currencyCode ?? settings.currencyCode,
    );
    if (currency == null) return null;
    final price = await _getIndexPrice(
      network: settings.environment.isTestnet
          ? BitcoinNetwork.testnet
          : BitcoinNetwork.mainnet,
      currency: currency,
    );
    switch (price) {
      case Ok(:final value):
        return value.fiatAmount;
      case Err(:final failure):
        log.warning('Send price unavailable: ${failure.runtimeType}');
        return null;
    }
  }
}
