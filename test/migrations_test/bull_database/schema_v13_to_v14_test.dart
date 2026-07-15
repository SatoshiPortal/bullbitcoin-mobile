import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v13.dart' as v13;
import 'generated/schema_v14.dart' as v14;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v13 to v14 preserves wallets and leaves new behavior unset', () async {
    final schema = await verifier.schemaAt(13);
    final oldDb = v13.DatabaseAtV13(schema.newConnection());

    await oldDb
        .into(oldDb.walletMetadatas)
        .insert(
          v13.WalletMetadatasCompanion.insert(
            id: 'wallet-1',
            masterFingerprint: 'f00dbabe',
            xpubFingerprint: 'deadbeef',
            isEncryptedVaultTested: 1,
            isPhysicalBackupTested: 0,
            xpub: 'xpub-test',
            externalPublicDescriptor: 'external-descriptor',
            internalPublicDescriptor: 'internal-descriptor',
            signer: 'local',
            isDefault: 1,
            label: const Value('Primary wallet'),
          ),
        );
    await oldDb.close();

    final db = SqliteDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 14);
    await db.close();

    final migratedDb = v14.DatabaseAtV14(schema.newConnection());
    final wallet = await migratedDb
        .select(migratedDb.walletMetadatas)
        .getSingle();

    expect(wallet.id, 'wallet-1');
    expect(wallet.label, 'Primary wallet');
    expect(wallet.isDefault, 1);
    expect(wallet.hideOnHome, isNull);
    expect(wallet.autoSweepEnabled, isNull);

    await migratedDb.close();
  });
}
