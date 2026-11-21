import 'package:preferences/preferences.dart'
    show AmountDisplayPreferences, AmountDisplayPreferencesReader;

final class WatchCoinsAmountDisplayUsecase {
  final AmountDisplayPreferencesReader _preferences;

  const WatchCoinsAmountDisplayUsecase(this._preferences);

  Stream<AmountDisplayPreferences?> execute() =>
      _preferences.watchDisplayPreferences();
}
