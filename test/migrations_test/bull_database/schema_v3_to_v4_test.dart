import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  group('v3 to v4: wallet_metadatas', () {
    test('source column to signer ', () async {
      // Get schema at version 3
      final schema = await verifier.schemaAt(3);

      // Create database with v3 schema and add test data
      final oldDb = v3.DatabaseAtV3(schema.newConnection());

      // Insert test data with different source values
      await oldDb
          .into(oldDb.walletMetadatas)
          .insert(
            v3.WalletMetadatasCompanion.insert(
              id: 'elwpkh([d2b5406d/84h/1667h/0h])',
              masterFingerprint: '12345678',
              xpubFingerprint: '87654321',
              isEncryptedVaultTested: false,
              isPhysicalBackupTested: false,
              xpub: 'xpub123...',
              externalPublicDescriptor:
                  'wpkh([12345678/84h/0h/0h]xpub123.../0/*)',
              internalPublicDescriptor:
                  'wpkh([12345678/84h/0h/0h]xpub123.../1/*)',
              source: 'mnemonic',
              isDefault: true,
            ),
          );
      await oldDb
          .into(oldDb.walletMetadatas)
          .insert(
            v3.WalletMetadatasCompanion.insert(
              id: 'elwpkh([d2b5406d/84h/1668h/0h])',
              masterFingerprint: '87654321',
              xpubFingerprint: '12345678',
              isEncryptedVaultTested: true,
              isPhysicalBackupTested: true,
              xpub: 'xpub456...',
              externalPublicDescriptor:
                  'wpkh([87654321/84h/0h/0h]xpub456.../0/*)',
              internalPublicDescriptor:
                  'wpkh([87654321/84h/0h/0h]xpub456.../1/*)',
              source: 'descriptors',
              isDefault: false,
            ),
          );
      await oldDb
          .into(oldDb.walletMetadatas)
          .insert(
            v3.WalletMetadatasCompanion.insert(
              id: 'wallet3',
              masterFingerprint: '11111111',
              xpubFingerprint: '22222222',
              isEncryptedVaultTested: false,
              isPhysicalBackupTested: false,
              xpub: 'xpub789...',
              externalPublicDescriptor:
                  'wpkh([11111111/84h/0h/0h]xpub789.../0/*)',
              internalPublicDescriptor:
                  'wpkh([11111111/84h/0h/0h]xpub789.../1/*)',
              source: 'xpub',
              isDefault: false,
            ),
          );

      await oldDb.close();

      // Run the migration to v4
      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      await db.close();

      // Verify the migrated data using v4 schema
      final migratedDb = v4.DatabaseAtV4(schema.newConnection());

      // Check that all records are still present
      final allWallets =
          await migratedDb.select(migratedDb.walletMetadatas).get();
      expect(allWallets.length, 3);

      // Verify the migration mappings
      final wallet1 = allWallets.firstWhere(
        (w) => w.id == 'elwpkh([d2b5406d/84h/1776h/0h])',
      );
      expect(wallet1.signer, 'local');
      expect(wallet1.isDefault, true);
      expect(wallet1.signerDevice, null);

      final wallet2 = allWallets.firstWhere(
        (w) => w.id == 'elwpkh([d2b5406d/84h/1h/0h])',
      );
      expect(wallet2.signer, 'remote');
      expect(wallet2.isDefault, false);
      expect(wallet2.signerDevice, null);

      final wallet3 = allWallets.firstWhere((w) => w.id == 'wallet3');
      expect(wallet3.signer, 'none');
      expect(wallet3.isDefault, false);

      await migratedDb.close();
    });

    test('unknown source value', () async {
      // Get schema at version 3
      final schema = await verifier.schemaAt(3);

      // Create database with v3 schema and add test data with unknown source
      final oldDb = v3.DatabaseAtV3(schema.newConnection());

      await oldDb
          .into(oldDb.walletMetadatas)
          .insert(
            v3.WalletMetadatasCompanion.insert(
              id: 'wallet_unknown',
              masterFingerprint: '99999999',
              xpubFingerprint: '88888888',
              isEncryptedVaultTested: false,
              isPhysicalBackupTested: false,
              xpub: 'xpub999...',
              externalPublicDescriptor:
                  'wpkh([99999999/84h/0h/0h]xpub999.../0/*)',
              internalPublicDescriptor:
                  'wpkh([99999999/84h/0h/0h]xpub999.../1/*)',
              source: 'unknown_source',
              isDefault: false,
            ),
          );

      await oldDb.close();

      // Run the migration to v4
      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      await db.close();

      // Verify the migrated data
      final migratedDb = v4.DatabaseAtV4(schema.newConnection());
      final wallet =
          await migratedDb.select(migratedDb.walletMetadatas).getSingle();

      // Unknown source should map to Signer.none
      expect(wallet.signer, 'none');
      expect(wallet.id, 'wallet_unknown');

      await migratedDb.close();
    });

    test('empty table', () async {
      // Get schema at version 3
      final schema = await verifier.schemaAt(3);

      // Create database with v3 schema (no data)
      final oldDb = v3.DatabaseAtV3(schema.newConnection());
      await oldDb.close();

      // Run the migration to v4
      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      await db.close();

      // Verify the migrated database is empty
      final migratedDb = v4.DatabaseAtV4(schema.newConnection());
      final allWallets =
          await migratedDb.select(migratedDb.walletMetadatas).get();
      expect(allWallets.length, 0);
      await migratedDb.close();
    });

    test('liquid testnet cointype', () async {
      // Get schema at version 3
      final schema = await verifier.schemaAt(3);

      // Create database with v3 schema and add test data
      final oldDb = v3.DatabaseAtV3(schema.newConnection());

      // Insert test data with different source values
      await oldDb
          .into(oldDb.walletMetadatas)
          .insert(
            v3.WalletMetadatasCompanion.insert(
              id: 'elwpkh([d2b5406d/84h/1668h/0h])',
              masterFingerprint: 'x',
              xpubFingerprint: 'x',
              isEncryptedVaultTested: false,
              isPhysicalBackupTested: false,
              xpub: 'x',
              externalPublicDescriptor: 'x',
              internalPublicDescriptor: 'x',
              source: 'local',
              isDefault: false,
            ),
          );

      await oldDb.close();

      // Run the migration to v5
      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      await db.close();

      // Verify the migrated data using v4 schema
      final migratedDb = v4.DatabaseAtV4(schema.newConnection());

      // Check that all records are still present
      final wallet1 =
          await migratedDb.select(migratedDb.walletMetadatas).getSingle();

      expect(wallet1.id, 'elwpkh([d2b5406d/84h/1h/0h])');
      expect(wallet1.signerDevice, null);
      await migratedDb.close();
    });
  });

  group('v3 to v4: delete wallet_address_history', () {
    test('wallet_addresses created', () async {
      // Get schema at version 3
      final schema = await verifier.schemaAt(3);

      // Run the migration to v4
      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      await db.close();

      // Verify the migrated data using v4 schema
      final newDb = v4.DatabaseAtV4(schema.newConnection());

      expect(await newDb.select(newDb.walletAddresses).get(), []);
    });

    test('ensure no duplicate can be created in wallet_addresses', () async {
      final addressA = v4.WalletAddressesData(
        address: 'A',
        walletId: '1',
        index: 0,
        isChange: false,
        balanceSat: 0,
        nrOfTransactions: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Get schema at version 3
      final schema = await verifier.schemaAt(3);

      // Run the migration to v4
      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      await db.close();

      // Verify the migrated data using v4 schema
      final newDb = v4.DatabaseAtV4(schema.newConnection());

      await newDb.into(newDb.walletAddresses).insert(addressA);

      // expect the second insert to throw
      expect(
        () async => await newDb.into(newDb.walletAddresses).insert(addressA),
        throwsA(isA<SqliteException>()),
      );

      // there is a single value in the table
      expect(await newDb.select(newDb.walletAddresses).get(), [addressA]);
    });
  });
}
