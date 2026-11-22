import 'package:bitcoin_price/src/domain/bitcoin_price_failure.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart'
    show RuntimeDisplayPreferencesReader;
import 'package:primitives/primitives.dart';

class ReadPriceCurrencyUsecase {
  final RuntimeDisplayPreferencesReader _preferences;

  const ReadPriceCurrencyUsecase(this._preferences);

  @useResult
  Future<Result<String, BitcoinPriceFailure>> execute() async =>
      (await _preferences.readCurrency()).mapErr(
        (failure) => BitcoinPricePreferencesFailure(failure.logMessage),
      );
}
