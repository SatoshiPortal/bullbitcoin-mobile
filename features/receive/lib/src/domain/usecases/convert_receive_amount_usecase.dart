import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';

import '../receive_failure.dart';

import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, Err, Ok, Result;

/// [amountSat] in [currencyCode], or in the settings currency when none is
/// given. Without an amount, the price of one bitcoin. Without a price,
/// [ReceivePriceUnavailableFailure]: receiving works on, with no fiat value.
class ConvertReceiveAmountUsecase {
  final Preferences _getSettingsUsecase;
  final IndexPriceReader _getIndexPrice;

  const ConvertReceiveAmountUsecase({
    required this._getSettingsUsecase,
    required this._getIndexPrice,
  });

  @useResult
  Future<Result<double, ReceiveFailure>> execute({
    BigInt? amountSat,
    String? currencyCode,
  }) async {
    final SettingsEntity settings;
    try {
      switch (await _getSettingsUsecase.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err(:final failure):
          log.warning(
            'Receive preferences unavailable: ${failure.runtimeType}',
          );
          return const Err(ReceiveUnexpectedFailure('Preferences read failed'));
      }
    } on Exception catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.severe(
        message: 'Failed to read the settings for the receive price',
        error: e.runtimeType,
        trace: st,
      );
      return Err(ReceiveUnexpectedFailure(e.toString()));
    }
    final code = currencyCode ?? settings.currencyCode;
    final currency = SupportedCurrency.tryFromCode(code);
    if (currency == null) {
      return Err(
        ReceivePriceUnavailableFailure('Currency not available: $code'),
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
    switch (price) {
      case Ok(:final value):
        return Ok(
          amountSat == null ? value.fiatAmount : value.fiatValueOf(amountSat),
        );
      case Err(:final failure):
        log.warning('Receive price unavailable: ${failure.runtimeType}');
        return Err(ReceivePriceUnavailableFailure(failure.logMessage));
    }
  }
}
