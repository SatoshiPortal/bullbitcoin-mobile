part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [Settings])
class SettingsLocalDatasource extends DatabaseAccessor<SqliteDatabase>
    with _$SettingsLocalDatasourceMixin {
  SettingsLocalDatasource(super.attachedDatabase);

  Future<void> store(SettingsRow row) {
    return into(settings).insert(row.toCompanion(true));
  }

  Future<SettingsRow> fetchById(int id) {
    return attachedDatabase.managers.settings
        .filter((f) => f.id(id))
        .getSingle();
  }

  Future<void> patchEnvironment({
    required int id,
    required String environment,
  }) {
    return attachedDatabase.managers.settings.update(
      (f) => f(id: Value(id), environment: Value(environment)),
    );
  }

  Future<void> patchBitcoinUnit({
    required int id,
    required String bitcoinUnit,
  }) {
    return attachedDatabase.managers.settings.update(
      (f) => f(id: Value(id), bitcoinUnit: Value(bitcoinUnit)),
    );
  }

  Future<void> patchLanguage({required int id, required String language}) {
    return attachedDatabase.managers.settings.update(
      (f) => f(id: Value(id), language: Value(language)),
    );
  }

  Future<void> patchCurrency({required int id, required String currency}) {
    return attachedDatabase.managers.settings.update(
      (f) => f(id: Value(id), currency: Value(currency)),
    );
  }

  Future<void> patchHideAmounts({required int id, required bool hideAmounts}) {
    return attachedDatabase.managers.settings.update(
      (f) => f(id: Value(id), hideAmounts: Value(hideAmounts)),
    );
  }

  Future<void> patchIsSuperuser({required int id, required bool isSuperuser}) {
    return attachedDatabase.managers.settings.update(
      (f) => f(id: Value(id), isSuperuser: Value(isSuperuser)),
    );
  }

  Future<void> patchIsDevModeEnabled({
    required int id,
    required bool isDevModeEnabled,
  }) {
    return attachedDatabase.managers.settings.update(
      (f) => f(id: Value(id), isDevModeEnabled: Value(isDevModeEnabled)),
    );
  }

  Future<void> patchUseTorProxy({required int id, required bool useTorProxy}) {
    return attachedDatabase.managers.settings.update(
      (f) => f(id: Value(id), useTorProxy: Value(useTorProxy)),
    );
  }

  Future<void> patchTorProxyPort({required int id, required int torProxyPort}) {
    return attachedDatabase.managers.settings.update(
      (f) => f(id: Value(id), torProxyPort: Value(torProxyPort)),
    );
  }

  Future<void> patchThemeMode({required int id, required String themeMode}) {
    return attachedDatabase.managers.settings.update(
      (f) => f(id: Value(id), themeMode: Value(themeMode)),
    );
  }
}
