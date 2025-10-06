import 'package:bb_mobile/core/settings/data/settings_model.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';

class SettingsDatasource {
  final SqliteDatabase _sqlite;

  SettingsDatasource({required SqliteDatabase sqlite}) : _sqlite = sqlite;

  Future<void> store(SettingsModel model) async {
    await _sqlite.managers.settings.create(
      (s) => s(
        id: Value(model.id),
        environment: model.environment.name,
        bitcoinUnit: model.bitcoinUnit.name,
        currency: model.currency,
        language: model.language.name,
        hideAmounts: model.hideAmounts,
        isSuperuser: model.isSuperuser,
        themeMode: Value(model.themeMode.name),
      ),
    );
  }

  Future<SettingsModel> fetch() async {
    final row =
        await _sqlite.managers.settings.filter((f) => f.id(1)).getSingle();
    return SettingsModel(
      id: row.id,
      environment: Environment.fromName(row.environment),
      bitcoinUnit: BitcoinUnit.fromName(row.bitcoinUnit),
      language: Language.fromName(row.language),
      currency: row.currency,
      hideAmounts: row.hideAmounts,
      isSuperuser: row.isSuperuser,
      themeMode: AppThemeMode.fromName(row.themeMode),
    );
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

  Future<void> setThemeMode(AppThemeMode themeMode) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), themeMode: Value(themeMode.name)),
    );
  }
}
