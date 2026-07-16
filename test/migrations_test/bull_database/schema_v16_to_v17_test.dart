import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test(
    'v16 to v17 creates default-off metadata backup state storage',
    () async {
      final schema = await verifier.schemaAt(16);
      final database = SqliteDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 17);
      await database
          .into(database.walletMetadataBackupStates)
          .insert(
            WalletMetadataBackupStatesCompanion.insert(id: const Value(1)),
          );
      final row = await database
          .select(database.walletMetadataBackupStates)
          .getSingle();

      expect(row.enabled, isFalse);
      expect(row.dirty, isFalse);
      expect(row.dirtyRevision, 0);
      expect(row.remoteEtag, isNull);
      expect(row.remoteGeneration, isNull);
      expect(row.blockedRemoteEtag, isNull);

      await database.close();
    },
  );
}
