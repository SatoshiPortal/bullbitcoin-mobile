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

  Future<bool?> readPendingExchangeAccess();
  Future<void> writePendingExchangeAccess(bool enabled);

  Future<bool?> readPendingBackgroundTasks();
  Future<void> writePendingBackgroundTasks(bool enabled);

  Future<bool?> readPendingScreenPrivacy();
  Future<void> writePendingScreenPrivacy(bool enabled);

  Future<String?> readPendingNetwork();
  Future<void> writePendingNetwork(String name);
  Future<void> clearPendingNetwork();

  Future<void> clearAllPending();
}

class WizardLocalDatasourceImpl implements WizardLocalDatasource {
  Future<void> _requireWrite(Future<bool> result) async {
    if (!await result) throw Exception('Wizard preferences write failed');
  }

  static const _pendingExchangeKey = 'wizard_pending_exchange_access';
  static const _versionKey = 'wizard_completed_version';
  static const _pendingVersionKey = 'wizard_pending_version';
  static const _pendingLanguageKey = 'wizard_pending_language';
  static const _pendingThemeKey = 'wizard_pending_theme_mode';
  static const _pendingCurrencyKey = 'wizard_pending_currency';
  static const _pendingErrorReportingKey = 'wizard_pending_error_reporting';
  static const _pendingBackgroundTasksKey = 'wizard_pending_background_tasks';
  static const _pendingScreenPrivacyKey = 'wizard_pending_screen_privacy';
  static const _pendingNetworkKey = 'wizard_pending_network';

  @override
  Future<bool?> readPendingScreenPrivacy() async =>
      (await SharedPreferences.getInstance()).getBool(_pendingScreenPrivacyKey);

  @override
  Future<void> writePendingScreenPrivacy(bool enabled) async {
    if (!await (await SharedPreferences.getInstance()).setBool(
      _pendingScreenPrivacyKey,
      enabled,
    )) {
      throw Exception('Could not stage the screen privacy choice');
    }
  }

  @override
  Future<String?> readPendingNetwork() async =>
      (await SharedPreferences.getInstance()).getString(_pendingNetworkKey);

  @override
  Future<void> writePendingNetwork(String name) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_pendingNetworkKey, name)) {
      throw Exception('Could not stage the network choice');
    }
  }

  @override
  Future<void> clearPendingNetwork() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_pendingNetworkKey)) {
      throw Exception('Could not acknowledge the network choice');
    }
  }

  @override
  Future<int?> readCompletedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_versionKey);
  }

  @override
  Future<void> writeCompletedVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await _requireWrite(prefs.setInt(_versionKey, version));
  }

  @override
  Future<int?> readPendingVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pendingVersionKey);
  }

  @override
  Future<void> writePendingVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await _requireWrite(prefs.setInt(_pendingVersionKey, version));
  }

  @override
  Future<String?> readPendingLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingLanguageKey);
  }

  @override
  Future<void> writePendingLanguage(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await _requireWrite(prefs.setString(_pendingLanguageKey, name));
  }

  @override
  Future<String?> readPendingThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingThemeKey);
  }

  @override
  Future<void> writePendingThemeMode(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await _requireWrite(prefs.setString(_pendingThemeKey, name));
  }

  @override
  Future<String?> readPendingCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingCurrencyKey);
  }

  @override
  Future<void> writePendingCurrency(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await _requireWrite(prefs.setString(_pendingCurrencyKey, code));
  }

  @override
  Future<bool?> readPendingErrorReporting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingErrorReportingKey);
  }

  @override
  Future<void> writePendingErrorReporting(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await _requireWrite(prefs.setBool(_pendingErrorReportingKey, enabled));
  }

  @override
  Future<bool?> readPendingExchangeAccess() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingExchangeKey);
  }

  @override
  Future<void> writePendingExchangeAccess(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await _requireWrite(prefs.setBool(_pendingExchangeKey, enabled));
  }

  @override
  Future<bool?> readPendingBackgroundTasks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingBackgroundTasksKey);
  }

  @override
  Future<void> writePendingBackgroundTasks(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await _requireWrite(prefs.setBool(_pendingBackgroundTasksKey, enabled));
  }

  @override
  Future<void> clearAllPending() async {
    final prefs = await SharedPreferences.getInstance();
    await _requireWrite(prefs.remove(_pendingBackgroundTasksKey));
    await _requireWrite(prefs.remove(_pendingExchangeKey));
    await _requireWrite(prefs.remove(_pendingLanguageKey));
    await _requireWrite(prefs.remove(_pendingThemeKey));
    await _requireWrite(prefs.remove(_pendingCurrencyKey));
    await _requireWrite(prefs.remove(_pendingErrorReportingKey));
    await _requireWrite(prefs.remove(_pendingNetworkKey));
    await _requireWrite(prefs.remove(_pendingScreenPrivacyKey));
    await _requireWrite(prefs.remove(_pendingVersionKey));
  }
}
