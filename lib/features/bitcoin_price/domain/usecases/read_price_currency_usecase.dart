import 'package:preferences/preferences.dart'
    show RuntimeDisplayPreferencesReader;

class ReadPriceCurrencyUsecase {
  final RuntimeDisplayPreferencesReader _preferences;

  const ReadPriceCurrencyUsecase(this._preferences);

  Future<String> execute() => _preferences.readCurrency();
}
