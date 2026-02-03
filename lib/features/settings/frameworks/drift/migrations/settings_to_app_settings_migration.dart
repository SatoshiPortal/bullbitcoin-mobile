import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/features/settings/frameworks/drift/app_settings_db_enums.dart';
import 'package:drift/drift.dart';

/// Migration function to populate app_settings table from existing settings table.
///
/// This function extracts general app-wide settings from the old settings table
/// and migrates them to the new app_settings table, leaving feature-specific
/// settings (Tor, error reporting) in the old settings table.
///
/// Field mappings:
/// - environment (text) → environmentMode (enum)
/// - currency (text) → fiatCurrencyCode (text, stored as code like "USD")
/// - bitcoinUnit (text) → bitcoinUnit (enum)
/// - language (text) → languageTag (BCP-47 format like "en-US", "fr-FR")
/// - hideAmounts (bool) → hideAmounts (bool)
/// - isSuperuser (bool) → superuserModeEnabled (bool)
/// - isDevModeEnabled (bool) → featureLevel (enum: alpha if true, stable if false)
/// - themeMode (text) → themeMode (enum)
///
/// Can be called from the main migration strategy.
class SettingsToAppSettingsMigration {
  static Future<void> migrate(Migrator m, Schema13 schema13) async {
    // Create the new app_settings table first (with default values defined in schema)
    await m.createTable(schema13.appSettings);

    // Get the current db instance
    final db = m.database as SqliteDatabase;

    // Get the existing settings row (there should only be one)
    final existingSettings = await db.select(db.settings).getSingleOrNull();

    // If no settings exist, insert a row to trigger defaults
    // The schema defaults will be used for all columns
    if (existingSettings == null) {
      await db.into(db.appSettings).insert(const AppSettingsCompanion());
      return;
    }

    // Map old settings to new app_settings
    // Convert isDevModeEnabled (bool) to featureLevel (enum)
    final featureLevel = existingSettings.isDevModeEnabled
        ? FeatureLevelDb.alpha
        : FeatureLevelDb.stable;

    // Convert currency text to uppercase code (old DB stored lowercase enum names)
    final currencyCode = existingSettings.currency.toUpperCase();

    // Parse bitcoinUnit
    final bitcoinUnit = existingSettings.bitcoinUnit.toLowerCase() == 'sats'
        ? BitcoinUnitDb.sats
        : BitcoinUnitDb.btc;

    // Parse themeMode
    final themeMode = switch (existingSettings.themeMode.toLowerCase()) {
      'light' => ThemeModeDb.light,
      'dark' => ThemeModeDb.dark,
      _ => ThemeModeDb.system,
    };

    // Parse environmentMode
    final environmentMode = existingSettings.environment.toLowerCase() == 'test'
        ? EnvironmentModeDb.test
        : EnvironmentModeDb.production;

    // Parse language - convert old language code to BCP-47 format
    // Old format was just language code like "en", we need to create BCP-47 tag
    final languageTag = _toBcp47Tag(existingSettings.language);

    // Step 2: Insert migrated data into app_settings
    await db
        .into(db.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            fiatCurrencyCode: Value(currencyCode),
            bitcoinUnit: Value(bitcoinUnit),
            languageTag: Value(languageTag),
            themeMode: Value(themeMode),
            hideAmounts: Value(existingSettings.hideAmounts),
            environmentMode: Value(environmentMode),
            superuserModeEnabled: Value(existingSettings.isSuperuser),
            featureLevel: Value(featureLevel),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Convert old language code to BCP-47 tag based on Language enum definitions
  static String _toBcp47Tag(String languageCode) {
    return switch (languageCode.toLowerCase()) {
      'en' => 'en-US',
      'fr' => 'fr-FR',
      'es' => 'es-ES',
      'fi' => 'fi-FI',
      'uk' => 'uk-UA',
      'ru' => 'ru-RU',
      'de' => 'de-DE',
      'it' => 'it-IT',
      'pt' => 'pt-PT',
      'zh' => 'zh-CN',
      _ => 'en-US', // Default to en-US if unknown
    };
  }
}
