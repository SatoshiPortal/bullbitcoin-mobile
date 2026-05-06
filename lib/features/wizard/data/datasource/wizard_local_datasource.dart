import 'package:shared_preferences/shared_preferences.dart';

/// Typed accessors over the wizard's slice of [SharedPreferences]. The
/// only file in the feature that knows about pref key names — repository
/// and usecases call domain-named methods rather than raw `getString` on
/// stringly-typed keys.
abstract class WizardLocalDatasource {
  Future<int?> readCompletedVersion();
  Future<void> writeCompletedVersion(int version);

  Future<int?> readPendingVersion();
  Future<void> writePendingVersion(int version);

  Future<String?> readPendingLanguage();
  Future<void> writePendingLanguage(String name);

  Future<String?> readPendingThemeMode();
  Future<void> writePendingThemeMode(String name);

  Future<String?> readPendingCurrency();
  Future<void> writePendingCurrency(String code);

  Future<bool?> readPendingErrorReporting();
  Future<void> writePendingErrorReporting(bool enabled);

  Future<void> clearAllPending();
}

class WizardLocalDatasourceImpl implements WizardLocalDatasource {
  static const _versionKey = 'wizard_completed_version';
  static const _pendingVersionKey = 'wizard_pending_version';
  static const _pendingLanguageKey = 'wizard_pending_language';
  static const _pendingThemeKey = 'wizard_pending_theme_mode';
  static const _pendingCurrencyKey = 'wizard_pending_currency';
  static const _pendingErrorReportingKey = 'wizard_pending_error_reporting';

  @override
  Future<int?> readCompletedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_versionKey);
  }

  @override
  Future<void> writeCompletedVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_versionKey, version);
  }

  @override
  Future<int?> readPendingVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pendingVersionKey);
  }

  @override
  Future<void> writePendingVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pendingVersionKey, version);
  }

  @override
  Future<String?> readPendingLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingLanguageKey);
  }

  @override
  Future<void> writePendingLanguage(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingLanguageKey, name);
  }

  @override
  Future<String?> readPendingThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingThemeKey);
  }

  @override
  Future<void> writePendingThemeMode(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingThemeKey, name);
  }

  @override
  Future<String?> readPendingCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingCurrencyKey);
  }

  @override
  Future<void> writePendingCurrency(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingCurrencyKey, code);
  }

  @override
  Future<bool?> readPendingErrorReporting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingErrorReportingKey);
  }

  @override
  Future<void> writePendingErrorReporting(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingErrorReportingKey, enabled);
  }

  @override
  Future<void> clearAllPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingVersionKey);
    await prefs.remove(_pendingLanguageKey);
    await prefs.remove(_pendingThemeKey);
    await prefs.remove(_pendingCurrencyKey);
    await prefs.remove(_pendingErrorReportingKey);
  }
}
