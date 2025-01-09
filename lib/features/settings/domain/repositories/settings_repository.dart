abstract class SettingsRepository {
  Future<String> getDefaultCurrency();
  Future<void> setDefaultCurrency(String currencyCode);
}
