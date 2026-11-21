import 'package:bitcoin_price/src/domain/bitcoin_price_failure.dart';
import 'package:preferences/preferences.dart'
    show RuntimeDisplayPreferencesReader;
import 'package:primitives/primitives.dart';

class WatchPriceCurrencyUsecase {
  final RuntimeDisplayPreferencesReader _preferences;

  const WatchPriceCurrencyUsecase(this._preferences);

  Stream<Result<String, BitcoinPriceFailure>> execute() =>
      _preferences.currencyChangeStream.map(
        (result) => result.mapErr(
          (failure) => BitcoinPricePreferencesFailure(failure.logMessage),
        ),
      );
}
