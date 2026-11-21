import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:preferences/preferences.dart'
    show AmountDisplayPreferencesReader;

final class WatchBuyBitcoinUnitUsecase {
  final AmountDisplayPreferencesReader _preferences;

  const WatchBuyBitcoinUnitUsecase(this._preferences);

  Stream<BitcoinUnit?> execute() => _preferences
      .watchDisplayPreferences()
      .map((preferences) => preferences?.bitcoinUnit)
      .distinct();
}
