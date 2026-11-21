import 'package:preferences/preferences.dart'
    show AmountDisplayPreferences, AmountDisplayPreferencesReader;

final class WatchBitcoinPriceAmountDisplayUsecase {
  final AmountDisplayPreferencesReader _preferences;

  const WatchBitcoinPriceAmountDisplayUsecase(this._preferences);

  Stream<AmountDisplayPreferences?> execute() =>
      _preferences.watchDisplayPreferences();
}
