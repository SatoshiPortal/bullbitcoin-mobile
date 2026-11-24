import 'package:preferences/preferences.dart';
import 'package:swaps/order_swaps.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The price of one bitcoin in [currencyCode], or in the settings currency
/// when none is given, on the network of the settings. Without one,
/// [SwapPriceUnavailableFailure]: the transfer shows no fiat value then.
class GetSwapExchangeRateUsecase {
  final Preferences _getSettingsUsecase;
  final IndexPriceReader _getIndexPrice;

  const GetSwapExchangeRateUsecase({
    required this._getSettingsUsecase,
    required this._getIndexPrice,
  });

  @useResult
  Future<Result<double, SwapFailure>> execute({String? currencyCode}) async {
    final SettingsEntity settings;
    try {
      settings = (await _getSettingsUsecase.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the settings for the transfer price',
        error: e,
        trace: st,
      );
      return Err(SwapUnexpectedFailure('$e'));
    }
    final code = currencyCode ?? settings.currencyCode;
    final currency = SupportedCurrency.tryFromCode(code);
    if (currency == null) {
      return Err(SwapPriceUnavailableFailure('Currency not available: $code'));
    }
    final price = await _getIndexPrice(
      network: switch (settings.environment) {
        Environment.mainnet => BitcoinNetwork.mainnet,
        Environment.testnet => BitcoinNetwork.testnet,
        Environment.regtest => BitcoinNetwork.regtest,
      },
      currency: currency,
    );
    switch (price) {
      case Ok(:final value):
        return Ok(value.fiatAmount);
      case Err(:final failure):
        log.warning('Transfer price unavailable: ${failure.runtimeType}');
        return Err(SwapPriceUnavailableFailure(failure.logMessage));
    }
  }
}
