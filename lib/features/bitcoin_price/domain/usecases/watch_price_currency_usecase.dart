import 'package:preferences/preferences.dart'
    show RuntimeDisplayPreferencesReader;

class WatchPriceCurrencyUsecase {
  final RuntimeDisplayPreferencesReader _preferences;

  const WatchPriceCurrencyUsecase(this._preferences);

  Stream<String> execute() => _preferences.currencyChangeStream;
}
