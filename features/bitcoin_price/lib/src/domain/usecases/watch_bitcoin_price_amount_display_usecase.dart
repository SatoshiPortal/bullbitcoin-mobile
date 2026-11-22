import 'package:bitcoin_price/src/domain/bitcoin_price_failure.dart';
import 'package:preferences/preferences.dart'
    show AmountDisplayPreferences, AmountDisplayPreferencesReader;
import 'package:primitives/primitives.dart';

final class WatchBitcoinPriceAmountDisplayUsecase {
  final AmountDisplayPreferencesReader _preferences;

  const WatchBitcoinPriceAmountDisplayUsecase(this._preferences);

  Stream<Result<AmountDisplayPreferences, BitcoinPriceFailure>> execute() =>
      _preferences.watchDisplayPreferences().map(
        (result) => result.mapErr(
          (failure) => BitcoinPricePreferencesFailure(failure.logMessage),
        ),
      );
}
