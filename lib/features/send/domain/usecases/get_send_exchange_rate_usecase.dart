import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The price of one bitcoin in [currencyCode], or in the settings currency
/// when none is given, on the network of the settings. Without one,
/// [SendPriceUnavailableFailure]: send shows no fiat value then.
class GetSendExchangeRateUsecase {
  final GetSettingsUsecase _getSettingsUsecase;
  final IndexPriceReader _getIndexPrice;

  const GetSendExchangeRateUsecase({
    required this._getSettingsUsecase,
    required this._getIndexPrice,
  });

  @useResult
  Future<Result<double, SendFailure>> execute({String? currencyCode}) async {
    final SettingsEntity settings;
    try {
      settings = await _getSettingsUsecase.execute();
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the settings for the send price',
        error: e,
        trace: st,
      );
      return Err(SendUnexpectedFailure('$e'));
    }
    final code = currencyCode ?? settings.currencyCode;
    final currency = SupportedCurrency.tryFromCode(code);
    if (currency == null) {
      return Err(SendPriceUnavailableFailure('Currency not available: $code'));
    }
    final price = await _getIndexPrice(
      network: settings.environment.isTestnet
          ? BitcoinNetwork.testnet
          : BitcoinNetwork.mainnet,
      currency: currency,
    );
    switch (price) {
      case Ok(:final value):
        return Ok(value.fiatAmount);
      case Err(:final failure):
        log.warning('Send price unavailable: ${failure.runtimeType}');
        return Err(SendPriceUnavailableFailure(failure.logMessage));
    }
  }
}
