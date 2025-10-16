import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';

class SettingsModel {
  final int id;
  final Environment environment;
  final BitcoinUnit bitcoinUnit;
  final Language language;
  final String currency;
  final bool hideAmounts;
  final bool isSuperuser;
  final bool isDevModeEnabled;
  final AppThemeMode themeMode;

  const SettingsModel({
    required this.id,
    required this.environment,
    required this.bitcoinUnit,
    required this.language,
    required this.currency,
    required this.hideAmounts,
    required this.isSuperuser,
    required this.isDevModeEnabled,
    required this.themeMode,
  });

  SettingsRow toSqlite() {
    return SettingsRow(
      id: id,
      environment: environment.name,
      bitcoinUnit: bitcoinUnit.name,
      language: language.name,
      currency: currency,
      hideAmounts: hideAmounts,
      isSuperuser: isSuperuser,
      isDevModeEnabled: isDevModeEnabled,
      themeMode: themeMode.name,
    );
  }

  factory SettingsModel.fromSqlite(SettingsRow row) {
    return SettingsModel(
      id: row.id,
      environment: Environment.fromName(row.environment),
      bitcoinUnit: BitcoinUnit.fromName(row.bitcoinUnit),
      language: Language.fromName(row.language),
      currency: row.currency,
      hideAmounts: row.hideAmounts,
      isSuperuser: row.isSuperuser,
      isDevModeEnabled: row.isDevModeEnabled,
      themeMode: AppThemeMode.fromName(row.themeMode),
    );
  }
}
