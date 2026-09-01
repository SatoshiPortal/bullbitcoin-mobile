import 'package:shared_preferences/shared_preferences.dart';

typedef WizardPreferencesLoader = Future<SharedPreferences> Function();

final class WizardPersistenceException implements Exception {
  final String operation;

  const WizardPersistenceException(this.operation);
}

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

  Future<bool?> readPendingMetadataBackup();
  Future<void> writePendingMetadataBackup(bool enabled);

  Future<void> clearAllPending();
}

class WizardLocalDatasourceImpl implements WizardLocalDatasource {
  final WizardPreferencesLoader _loadPreferences;

  WizardLocalDatasourceImpl({WizardPreferencesLoader? loadPreferences})
    : _loadPreferences =
          loadPreferences ?? (() => SharedPreferences.getInstance());

  static const _versionKey = 'wizard_completed_version';
  static const _pendingVersionKey = 'wizard_pending_version';
  static const _pendingLanguageKey = 'wizard_pending_language';
  static const _pendingThemeKey = 'wizard_pending_theme_mode';
  static const _pendingCurrencyKey = 'wizard_pending_currency';
  static const _pendingErrorReportingKey = 'wizard_pending_error_reporting';
  static const _pendingMetadataBackupKey = 'wizard_pending_metadata_backup';

  @override
  Future<int?> readCompletedVersion() async {
    final prefs = await _loadPreferences();
    return prefs.getInt(_versionKey);
  }

  @override
  Future<void> writeCompletedVersion(int version) async {
    final prefs = await _loadPreferences();
    _require(await prefs.setInt(_versionKey, version), 'completed version');
  }

  @override
  Future<int?> readPendingVersion() async {
    final prefs = await _loadPreferences();
    return prefs.getInt(_pendingVersionKey);
  }

  @override
  Future<void> writePendingVersion(int version) async {
    final prefs = await _loadPreferences();
    _require(
      await prefs.setInt(_pendingVersionKey, version),
      'pending version',
    );
  }

  @override
  Future<String?> readPendingLanguage() async {
    final prefs = await _loadPreferences();
    return prefs.getString(_pendingLanguageKey);
  }

  @override
  Future<void> writePendingLanguage(String name) async {
    final prefs = await _loadPreferences();
    _require(await prefs.setString(_pendingLanguageKey, name), 'language');
  }

  @override
  Future<String?> readPendingThemeMode() async {
    final prefs = await _loadPreferences();
    return prefs.getString(_pendingThemeKey);
  }

  @override
  Future<void> writePendingThemeMode(String name) async {
    final prefs = await _loadPreferences();
    _require(await prefs.setString(_pendingThemeKey, name), 'theme');
  }

  @override
  Future<String?> readPendingCurrency() async {
    final prefs = await _loadPreferences();
    return prefs.getString(_pendingCurrencyKey);
  }

  @override
  Future<void> writePendingCurrency(String code) async {
    final prefs = await _loadPreferences();
    _require(await prefs.setString(_pendingCurrencyKey, code), 'currency');
  }

  @override
  Future<bool?> readPendingErrorReporting() async {
    final prefs = await _loadPreferences();
    return prefs.getBool(_pendingErrorReportingKey);
  }

  @override
  Future<void> writePendingErrorReporting(bool enabled) async {
    final prefs = await _loadPreferences();
    _require(
      await prefs.setBool(_pendingErrorReportingKey, enabled),
      'error reporting choice',
    );
  }

  @override
  Future<bool?> readPendingMetadataBackup() async {
    final prefs = await _loadPreferences();
    return prefs.getBool(_pendingMetadataBackupKey);
  }

  @override
  Future<void> writePendingMetadataBackup(bool enabled) async {
    final prefs = await _loadPreferences();
    _require(
      await prefs.setBool(_pendingMetadataBackupKey, enabled),
      'metadata backup choice',
    );
  }

  @override
  Future<void> clearAllPending() async {
    final prefs = await _loadPreferences();
    for (final key in const [
      _pendingVersionKey,
      _pendingLanguageKey,
      _pendingThemeKey,
      _pendingCurrencyKey,
      _pendingErrorReportingKey,
      _pendingMetadataBackupKey,
    ]) {
      _require(await prefs.remove(key), 'remove $key');
    }
  }

  void _require(bool persisted, String operation) {
    if (!persisted) throw WizardPersistenceException(operation);
  }
}
