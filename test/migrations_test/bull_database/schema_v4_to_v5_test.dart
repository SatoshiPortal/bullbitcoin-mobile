import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;

Future<void> main() async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  log = await Logger.init();

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  group('v4 to v5: wallet_metadatas', () {
    test('signer_device column and id migration', () async {
      // Get schema at version 3
      final schema = await verifier.schemaAt(4);

      // Create database with v3 schema and add test data
      final oldDb = v4.DatabaseAtV4(schema.newConnection());

      // Insert test data with different source values
      await oldDb
          .into(oldDb.walletMetadatas)
          .insert(
            v4.WalletMetadatasCompanion.insert(
              id: 'elwpkh([d2b5406d/84h/1667h/0h])',
              masterFingerprint: 'x',
              xpubFingerprint: 'x',
              isEncryptedVaultTested: false,
              isPhysicalBackupTested: false,
              xpub: 'x',
              externalPublicDescriptor: 'x',
              internalPublicDescriptor: 'x',
              signer: 'local',
              isDefault: true,
            ),
          );

      await oldDb.close();

      // Run the migration to v5
      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 5);
      await db.close();

      // Verify the migrated data using v4 schema
      final migratedDb = v5.DatabaseAtV5(schema.newConnection());

      // Check that all records are still present
      final wallet1 =
          await migratedDb.select(migratedDb.walletMetadatas).getSingle();

      expect(wallet1.id, 'elwpkh([d2b5406d/84h/1776h/0h])');
      expect(wallet1.signerDevice, null);
      await migratedDb.close();
    });
  });
}
