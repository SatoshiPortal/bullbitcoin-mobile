import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The price of one bitcoin in [currencyCode], on the network of the settings.
class GetPayExchangeRateUsecase {
  final GetSettingsUsecase _getSettingsUsecase;
  final IndexPriceReader _getIndexPrice;

  const GetPayExchangeRateUsecase({
    required this._getSettingsUsecase,
    required this._getIndexPrice,
  });

  @useResult
  Future<Result<double, PayFailure>> execute({
    required String currencyCode,
  }) async {
    final SettingsEntity settings;
    try {
      settings = await _getSettingsUsecase.execute();
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the settings for the pay price',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
    final currency = SupportedCurrency.tryFromCode(currencyCode);
    if (currency == null) {
      return Err(PayUnexpectedFailure('Currency not available: $currencyCode'));
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
      // Without a price there is nothing to estimate with: a zero rate would
      // pass any balance check.
      case Err(:final failure):
        log.warning('Pay price unavailable: ${failure.runtimeType}');
        return Err(PayQuoteUnavailableFailure(failure.logMessage));
    }
  }
}
