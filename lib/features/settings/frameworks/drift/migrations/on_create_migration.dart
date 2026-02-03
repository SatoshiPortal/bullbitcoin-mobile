import 'package:bb_mobile/core/storage/sqlite_database.dart';

/// Migration to seed default app_settings row on database creation.
///
/// This ensures that a single settings row exists from the start,
/// allowing the app to always read settings without null checks.
/// Schema defaults are used for all column values.
class AppSettingsOnCreateMigration {
  static Future<void> seed(SqliteDatabase database) async {
    // Insert a single row with schema defaults
    // The table schema defines defaults for all columns, so we just
    // need to insert an empty companion to trigger those defaults
    await database
        .into(database.appSettings)
        .insert(const AppSettingsCompanion());
  }
}
