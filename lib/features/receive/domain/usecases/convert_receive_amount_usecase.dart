import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;

/// [amountSat] in [currencyCode], or in the settings currency when none is
/// given. Without an amount, the price of one bitcoin. Without a price,
/// [ReceivePriceUnavailableFailure]: receiving works on, with no fiat value.
class ConvertReceiveAmountUsecase {
  final GetSettingsUsecase _getSettingsUsecase;
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
      settings = await _getSettingsUsecase.execute();
    } on Object catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.severe(
        message: 'Failed to read the settings for the receive price',
        error: e,
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
      network: settings.environment.isTestnet
          ? BitcoinNetwork.testnet
          : BitcoinNetwork.mainnet,
      currency: currency,
    );
    switch (price) {
      case Ok(:final value):
        return Ok(
          value.fiatValueOf(
            amountSat ?? ConversionConstants.satsAmountOfOneBitcoin,
          ),
        );
      case Err(:final failure):
        log.warning('Receive price unavailable: ${failure.runtimeType}');
        return Err(ReceivePriceUnavailableFailure(failure.logMessage));
    }
  }
}
