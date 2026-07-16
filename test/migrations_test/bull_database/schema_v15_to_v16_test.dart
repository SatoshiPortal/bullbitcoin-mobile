import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v16.dart' as v16;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v15 to v16 creates disabled clean keychain backup state', () async {
    final schema = await verifier.schemaAt(15);
    final db = SqliteDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 16);
    await db.close();

    final migratedDb = v16.DatabaseAtV16(schema.newConnection());
    await migratedDb
        .into(migratedDb.keychainManifestBackupStates)
        .insert(
          v16.KeychainManifestBackupStatesCompanion.insert(id: const Value(1)),
        );

    final row = await migratedDb
        .select(migratedDb.keychainManifestBackupStates)
        .getSingle();
    expect(row.enabled, 0);
    expect(row.dirty, 0);
    expect(row.dirtyRevision, 0);
    expect(row.remoteGeneration, 0);
    expect(row.remoteEtag, isNull);
    expect(row.unsupportedVersion, isNull);

    await migratedDb.close();
  });
}
