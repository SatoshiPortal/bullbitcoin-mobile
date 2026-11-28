import 'package:preferences/preferences.dart'
    show AmountDisplayPreferences, AmountDisplayPreferencesReader;

final class OverviewAmountDisplay {
  final AmountDisplayPreferencesReader _preferences;

  const OverviewAmountDisplay(this._preferences);

  /// Unknown preferences mask amounts until a readable value arrives.
  Stream<AmountDisplayPreferences?> watch() => _preferences
      .watchDisplayPreferences()
      .map((result) => result.fold((value) => value, (_) => null));
}
