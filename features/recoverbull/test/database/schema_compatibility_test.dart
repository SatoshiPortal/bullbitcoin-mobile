import 'dart:typed_data';

import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'generated/schema.dart';

/// Uses tables generated from the committed snapshot, independently of the
/// current app database. Changing Dart tables without updating the snapshot
/// must fail validation before the first version is released.
void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  test('initial creation matches the committed v1 schema', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await verifier.migrateAndValidate(
      database,
      1,
      options: const ValidationOptions(validateDropped: true),
    );
    await database.forceOpen();
    final state = await database.select(database.recoverbullState).getSingle();
    expect(state.permissionGranted, isFalse);
    expect(state.attemptMonitoringEnabled, isTrue);
  });

  test(
    'committed v1 validates and reopens without changing persisted rows',
    () async {
      final fixture = await verifier.schemaAt(1);
      addTearDown(fixture.rawDatabase.dispose);
      _seed(fixture.rawDatabase);
      final rows = _rows(fixture.rawDatabase);
      final schema = _schema(fixture.rawDatabase);

      var database = RecoverBullDatabase.forTesting(fixture.newConnection());
      await verifier.migrateAndValidate(
        database,
        1,
        options: const ValidationOptions(validateDropped: true),
      );
      await database.forceOpen();
      expect(_schema(fixture.rawDatabase), schema);
      expect(_rows(fixture.rawDatabase), rows);
      await database.close();

      database = RecoverBullDatabase.forTesting(fixture.newConnection());
      await database.forceOpen();
      expect(_schema(fixture.rawDatabase), schema);
      expect(_rows(fixture.rawDatabase), rows);
      expect(
        fixture.rawDatabase
            .select('PRAGMA user_version')
            .single['user_version'],
        1,
      );
      await database.close();
    },
  );

  test(
    'a newer schema is rejected without rewriting its version or data',
    () async {
      final fixture = await verifier.schemaAt(1);
      addTearDown(fixture.rawDatabase.dispose);
      _seed(fixture.rawDatabase);
      fixture.rawDatabase.execute('PRAGMA user_version = 2');
      final rows = _rows(fixture.rawDatabase);
      final schema = _schema(fixture.rawDatabase);
      final database = RecoverBullDatabase.forTesting(fixture.newConnection());
      await expectLater(
        database.forceOpen(),
        throwsA(
          isA<RecoverBullUnsupportedSchemaException>()
              .having((e) => e.from, 'from', 2)
              .having((e) => e.to, 'to', 1),
        ),
      );
      await database.close();
      expect(
        fixture.rawDatabase
            .select('PRAGMA user_version')
            .single['user_version'],
        2,
      );
      expect(_schema(fixture.rawDatabase), schema);
      expect(_rows(fixture.rawDatabase), rows);
    },
  );
}

void _seed(sqlite.Database database) {
  final digest = Uint8List.fromList(List.generate(32, (i) => i));
  database.execute(
    'INSERT INTO recoverbull_state (id, server_url_override, permission_granted, generation, revision) VALUES (1, ?, 1, 3, 4)',
    ['http://custom.onion'],
  );
  database.execute(
    "INSERT INTO recoverbull_backup_status (network, last_encrypted_backup_at, last_verified_encrypted_backup_at) VALUES ('mainnet', ?, ?)",
    ['2026-10-01T00:00:00.000Z', '2026-10-02T00:00:00.000Z'],
  );
  database.execute(
    'INSERT INTO recoverbull_monitored_backup (digest, expected_server_distinct_candidate_total, current_window, drive_account_hash, drive_file_id) VALUES (?, 7, 2, ?, ?)',
    [digest, 'opaque-account-hash', 'opaque-file-id'],
  );
  database.execute(
    'INSERT INTO recoverbull_drive_backup_cache (account_hash, drive_file_id, backup_digest, drive_file_created_at) VALUES (?, ?, ?, ?)',
    [
      'opaque-account-hash',
      'opaque-file-id',
      digest,
      '2026-10-01T00:00:00.000Z',
    ],
  );
  database.execute(
    'INSERT INTO recoverbull_acknowledged_alert (identity, acknowledged_at) VALUES (?, ?)',
    ['window-scoped-identity', '2026-10-02T00:00:00.000Z'],
  );
}

List<Map<String, Object?>> _schema(sqlite.Database database) => database
    .select(
      "SELECT name, sql FROM sqlite_schema WHERE name NOT LIKE 'sqlite_%' ORDER BY name",
    )
    .toList();

Map<String, List<Map<String, Object?>>> _rows(sqlite.Database database) => {
  for (final table in [
    'recoverbull_state',
    'recoverbull_backup_status',
    'recoverbull_monitored_backup',
    'recoverbull_drive_backup_cache',
    'recoverbull_acknowledged_alert',
  ])
    table: database.select('SELECT * FROM $table').toList(),
};
