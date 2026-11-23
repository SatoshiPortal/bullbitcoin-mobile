import 'package:preferences/preferences.dart'
    show AmountDisplayPreferences, AmountDisplayPreferencesReader;

final class WatchWalletAmountDisplayUsecase {
  final AmountDisplayPreferencesReader _preferences;

  const WatchWalletAmountDisplayUsecase(this._preferences);

  Stream<AmountDisplayPreferences?> execute() => _preferences
      .watchDisplayPreferences()
      .map((result) => result.fold((value) => value, (_) => null));
}
