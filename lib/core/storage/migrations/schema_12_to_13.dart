import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/features/settings/frameworks/drift/settings_to_app_settings_migration.dart';
import 'package:drift/drift.dart';

/// Migration from version 12 to 13
///
/// Changes:
/// - Creates new app_settings table for general app-wide settings
/// - Migrates data from settings table to app_settings table
/// - Old settings table remains for feature-specific settings (Tor, error reporting)
///
/// Field mappings:
/// - environment → environmentMode
/// - currency → fiatCurrency
/// - bitcoinUnit → bitcoinUnit
/// - language → language
/// - hideAmounts → hideAmounts
/// - isSuperuser → superuserModeEnabled
/// - isDevModeEnabled → featureLevel (alpha if enabled, stable if disabled)
/// - themeMode → themeMode
class Schema12To13 {
  static Future<void> migrate(Migrator m, Schema13 schema13) async {
    // Create and populate the new app_settings table
    await SettingsToAppSettingsMigration.migrate(m, schema13);
  }
}
