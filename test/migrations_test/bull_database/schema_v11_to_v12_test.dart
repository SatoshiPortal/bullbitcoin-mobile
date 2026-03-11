import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v11.dart' as v11;
import 'generated/schema_v12.dart' as v12;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  group('v11 to v12: labels table restructure', () {
    test('labels data migrated with ref renamed to reference', () async {
      final schema = await verifier.schemaAt(11);

      final oldDb = v11.DatabaseAtV11(schema.newConnection());

      await oldDb
          .into(oldDb.labels)
          .insert(
            v11.LabelsCompanion.insert(
              label: 'test-label',
              ref: 'abc123def456',
              type: 'tx',
              origin: const Value('wallet-1'),
            ),
          );

      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 12);
      await db.close();

      final migratedDb = v12.DatabaseAtV12(schema.newConnection());

      final allLabels = await migratedDb.select(migratedDb.labels).get();
      expect(allLabels.length, 1);

      final label = allLabels.first;
      expect(label.id, isNotNull);
      expect(label.label, 'test-label');
      expect(label.reference, 'abc123def456');
      expect(label.type, 'tx');
      expect(label.origin, 'wallet-1');

      await migratedDb.close();
    });

    test('multiple labels migrated with autoincrement ids', () async {
      final schema = await verifier.schemaAt(11);

      final oldDb = v11.DatabaseAtV11(schema.newConnection());

      await oldDb
          .into(oldDb.labels)
          .insert(
            v11.LabelsCompanion.insert(
              label: 'label-1',
              ref: 'ref-1',
              type: 'tx',
            ),
          );

      await oldDb
          .into(oldDb.labels)
          .insert(
            v11.LabelsCompanion.insert(
              label: 'label-2',
              ref: 'ref-2',
              type: 'address',
              origin: const Value('origin-2'),
            ),
          );

      await oldDb
          .into(oldDb.labels)
          .insert(
            v11.LabelsCompanion.insert(
              label: 'label-3',
              ref: 'ref-3',
              type: 'xpub',
            ),
          );

      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 12);
      await db.close();

      final migratedDb = v12.DatabaseAtV12(schema.newConnection());

      final allLabels = await migratedDb.select(migratedDb.labels).get();
      expect(allLabels.length, 3);

      // Verify each label has a unique id
      final ids = allLabels.map((l) => l.id).toSet();
      expect(ids.length, 3);

      // Verify data integrity
      final label1 = allLabels.firstWhere((l) => l.label == 'label-1');
      expect(label1.id, 1);
      expect(label1.reference, 'ref-1');
      expect(label1.type, 'tx');
      expect(label1.origin, isNull);

      final label2 = allLabels.firstWhere((l) => l.label == 'label-2');
      expect(label2.id, 2);
      expect(label2.reference, 'ref-2');
      expect(label2.type, 'address');
      expect(label2.origin, 'origin-2');

      final label3 = allLabels.firstWhere((l) => l.label == 'label-3');
      expect(label3.id, 3);
      expect(label3.reference, 'ref-3');
      expect(label3.type, 'xpub');

      await migratedDb.close();
    });
  });
}
