import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:drift/native.dart';
import 'package:preferences/testing.dart';

/// An in-memory owner database for tests unrelated to storage admission.
Future<PreferencesDatabase> createPreferencesDatabase({
  SqliteDatabase? copySettingsFrom,
}) async {
  final database = PreferencesDatabase(NativeDatabase.memory());
  final source = copySettingsFrom;
  final values = source == null
      ? [1, 'mainnet', 'sats', 'unitedStatesEnglish', 'USD', 0, 0, 0]
      : (await source
                .customSelect(
                  'SELECT id, environment, bitcoin_unit, language, currency, '
                  'hide_amounts, is_superuser, is_dev_mode_enabled FROM settings',
                )
                .getSingle())
            .data
            .values
            .toList();
  await database.customStatement(
    'INSERT INTO settings (id, environment, bitcoin_unit, language, currency, '
    'hide_amounts, is_superuser, is_dev_mode_enabled) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    values,
  );
  return database;
}
