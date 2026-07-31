import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:meta/meta.dart';

final class SweepDisplaySettings {
  final BitcoinUnit bitcoinUnit;
  final bool hideAmounts;
  final double exchangeRate;
  final String fiatCurrencyCode;

  const SweepDisplaySettings({
    required this.bitcoinUnit,
    required this.hideAmounts,
    required this.exchangeRate,
    required this.fiatCurrencyCode,
  });
}

/// Loads the display preferences and optional fiat hint used by the sweep UI.
class GetSweepDisplaySettingsUsecase {
  final GetSettingsUsecase _getSettings;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrency;

  GetSweepDisplaySettingsUsecase({
    required GetSettingsUsecase getSettingsUsecase,
    required ConvertSatsToCurrencyAmountUsecase
    convertSatsToCurrencyAmountUsecase,
  }) : _getSettings = getSettingsUsecase,
       _convertSatsToCurrency = convertSatsToCurrencyAmountUsecase;

  @useResult
  Future<Result<SweepDisplaySettings, SweepFailure>> execute() async {
    try {
      final settings = await _getSettings.execute();
      var rate = 0.0;
      try {
        rate = await _convertSatsToCurrency.execute(
          amountSat: BigInt.from(100000000),
          currencyCode: settings.currencyCode,
        );
      } on Exception catch (e, st) {
        // Fiat is only a hint; denomination and privacy preferences remain
        // useful when the exchange rate is temporarily unavailable.
        log.info('Sweep fiat hint unavailable', error: e, trace: st);
      }
      return Ok(
        SweepDisplaySettings(
          bitcoinUnit: settings.bitcoinUnit,
          hideAmounts: settings.hideAmounts ?? true,
          exchangeRate: rate,
          fiatCurrencyCode: settings.currencyCode,
        ),
      );
    } on Exception catch (e, st) {
      // Display preferences are optional for the transaction flow. The cubit
      // keeps privacy-safe defaults when this lookup fails.
      log.info('Sweep display settings unavailable', error: e, trace: st);
      return Err(SweepUnexpectedFailure(e.toString()));
    }
  }
}
