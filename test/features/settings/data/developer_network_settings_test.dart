import 'package:bb_mobile/features/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase database;
  late SettingsDatasource datasource;

  setUp(() async {
    database = SqliteDatabase(NativeDatabase.memory());
    datasource = SettingsDatasource(sqlite: database);
    await database.customStatement(
      "UPDATE settings SET environment = 'testnet', "
      'is_superuser = 1, is_dev_mode_enabled = 1 WHERE id = 1',
    );
    await database.customStatement(
      'CREATE TABLE setting_writes (value INTEGER)',
    );
    await database.customStatement(
      'CREATE TRIGGER count_settings_writes AFTER UPDATE ON settings '
      'BEGIN INSERT INTO setting_writes VALUES (1); END',
    );
  });

  tearDown(() => database.close());

  test('developer mode off commits mainnet in the same settings write', () async {
    await datasource.setIsDevMode(false);
    final row = await database
        .customSelect(
          'SELECT environment, is_dev_mode_enabled FROM settings WHERE id = 1',
        )
        .getSingle();
    expect(row.read<String>('environment'), 'mainnet');
    expect(row.read<int>('is_dev_mode_enabled'), 0);
    final writes = await database
        .customSelect('SELECT COUNT(*) AS count FROM setting_writes')
        .getSingle();
    expect(writes.read<int>('count'), 1);
  });

  test('startup read repairs a persisted unauthorized network', () async {
    await database.customStatement(
      'UPDATE settings SET is_dev_mode_enabled = 0 WHERE id = 1',
    );
    final settings = await datasource.fetch();
    expect(settings.environment.name, 'mainnet');
    expect(settings.isDevModeEnabled, isFalse);
  });

  test('an authorized testnet read does not rewrite settings', () async {
    final settings = await datasource.fetch();
    expect(settings.environment.name, 'testnet');
    expect(settings.isDevModeEnabled, isTrue);
    final writes = await database
        .customSelect('SELECT COUNT(*) AS count FROM setting_writes')
        .getSingle();
    expect(writes.read<int>('count'), 0);
  });
}
