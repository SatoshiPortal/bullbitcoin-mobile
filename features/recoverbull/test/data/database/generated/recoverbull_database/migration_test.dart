// dart format width=80
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:bull_recoverbull/src/data/database/recoverbull_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = RecoverBullDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test(
    'the schema upgrade preserves the existing state and receipts start empty',
    () async {
      const old = v1.RecoverbullStateData(
        id: 1,
        server: 'http://historical.onion',
        permissionGranted: 1,
        monitoringEnabled: 0,
        legacyImportComplete: 1,
        monitoringRevision: 27,
        generation: 3,
      );
      await verifier.testWithDataIntegrity(
        oldVersion: 1,
        newVersion: 2,
        createOld: v1.DatabaseAtV1.new,
        createNew: v2.DatabaseAtV2.new,
        openTestedDatabase: RecoverBullDatabase.new,
        createItems: (batch, oldDb) {
          batch.insert(oldDb.recoverbullState, old);
        },
        validateItems: (newDb) async {
          expect(
            await newDb.select(newDb.recoverbullState).getSingle(),
            v2.RecoverbullStateData(
              id: old.id,
              server: old.server,
              permissionGranted: old.permissionGranted,
              monitoringEnabled: old.monitoringEnabled,
              legacyImportComplete: old.legacyImportComplete,
              monitoringRevision: old.monitoringRevision,
              generation: old.generation,
            ),
          );
          expect(await newDb.select(newDb.legacyImportReceipts).get(), isEmpty);
          expect(
            await newDb.select(newDb.recoverbullWalletBackups).get(),
            isEmpty,
          );
        },
      );
    },
  );
}
