import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v15.dart' as v15;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v14 to v15 creates keychain manifest entries table', () async {
    final schema = await verifier.schemaAt(14);
    final db = SqliteDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 15);
    await db.close();

    final migratedDb = v15.DatabaseAtV15(schema.newConnection());
    await migratedDb
        .into(migratedDb.keychainManifestEntries)
        .insert(
          v15.KeychainManifestEntriesCompanion.insert(
            entryId: "fedcba98:39'/0'/12'/100'",
            parentFingerprint: 'fedcba98',
            bip85DerivationPath: "39'/0'/12'/100'",
            reservationId: 'btcpay_wallet_seed',
            entryType: 'walletSeed',
            ownerFeature: 'btcpay',
            bip85Application: 39,
            bip85Index: 100,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await migratedDb
        .into(migratedDb.keychainManifestWalletBindings)
        .insert(
          v15.KeychainManifestWalletBindingsCompanion.insert(
            walletId: 'btc-wallet',
            entryId: "fedcba98:39'/0'/12'/100'",
            childSeedFingerprint: '0123abcd',
            network: 'bitcoinMainnet',
            walletPurpose: 'bitcoin',
            scriptType: 'bip84',
            createdAt: 1,
            updatedAt: 1,
          ),
        );

    final rows = await migratedDb
        .select(migratedDb.keychainManifestEntries)
        .get();
    final bindings = await migratedDb
        .select(migratedDb.keychainManifestWalletBindings)
        .get();
    expect(rows.single.entryId, "fedcba98:39'/0'/12'/100'");
    expect(bindings.single.walletId, 'btc-wallet');

    await migratedDb.close();
  });
}
