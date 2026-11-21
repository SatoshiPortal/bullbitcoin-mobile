import 'package:preferences/preferences.dart'
    show RuntimeDisplayPreferencesReader;

class ReadPriceCurrencyUsecase {
  final RuntimeDisplayPreferencesReader _preferences;

  const ReadPriceCurrencyUsecase(this._preferences);

  Future<String> execute() => _preferences.readCurrency().then(
    (result) => result.fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    ),
  );
}
