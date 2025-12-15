import 'package:bb_mobile/core_deprecated/settings/data/settings_model.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:drift/drift.dart';

class SettingsDatasource {
  final SqliteDatabase _sqlite;

  SettingsDatasource({required SqliteDatabase sqlite}) : _sqlite = sqlite;

  Future<void> store(SettingsModel model) async {
    await _sqlite.into(_sqlite.settings).insert(model.toSqlite());
  }

  Future<SettingsModel> fetch() async {
    final row = await _sqlite.managers.settings
        .filter((f) => f.id(1))
        .getSingle();
    return SettingsModel.fromSqlite(row);
  }

  Future<void> setEnvironment(Environment env) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), environment: Value(env.name)),
    );
  }

  Future<void> setBitcoinUnit(BitcoinUnit bitcoinUnit) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), bitcoinUnit: Value(bitcoinUnit.name)),
    );
  }

  Future<void> setLanguage(Language language) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), language: Value(language.name)),
    );
  }

  Future<void> setCurrency(String currencyCode) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), currency: Value(currencyCode)),
    );
  }

  Future<void> setHideAmounts(bool hide) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), hideAmounts: Value(hide)),
    );
  }

  Future<void> setIsSuperuser(bool isSuperuser) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), isSuperuser: Value(isSuperuser)),
    );
  }

  Future<void> setIsDevMode(bool isEnabled) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), isDevModeEnabled: Value(isEnabled)),
    );
  }

  Future<void> setUseTorProxy(bool useTorProxy) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), useTorProxy: Value(useTorProxy)),
    );
  }

  Future<void> setTorProxyPort(int port) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), torProxyPort: Value(port)),
    );
  }

  Future<void> setThemeMode(AppThemeMode themeMode) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), themeMode: Value(themeMode.name)),
    );
  }
}
