import 'package:drift/native.dart';
import 'package:preferences/testing.dart';

Future<PreferencesDatabase> createPreferencesDatabase() async {
  final database = PreferencesDatabase(NativeDatabase.memory());
  await database.customStatement(
    'INSERT INTO settings (id, environment, bitcoin_unit, language, currency, '
    'hide_amounts, is_superuser, is_dev_mode_enabled) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    [1, 'mainnet', 'sats', 'unitedStatesEnglish', 'USD', 0, 0, 0],
  );
  return database;
}
