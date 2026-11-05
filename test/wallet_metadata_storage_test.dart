import 'package:bb_mobile/wallet_catalog_adapters.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:wallet/wallet.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final signer in Signer.values) {
    for (final device in <SignerDevice?>[null, ...SignerDevice.values]) {
      test(
        'existing metadata round trips ${signer.name}/${device?.name}',
        () async {
          final db = SqliteDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final catalog = SqliteWalletCatalog(sqlite: db);
          // Seed the persisted representation independently of the mapper.
          const id = '[aabbccdd/84h/0h/0h]';
          await db.customStatement(
            '''
INSERT INTO wallet_metadatas (
  id, master_fingerprint, xpub_fingerprint,
  is_encrypted_vault_tested, is_physical_backup_tested,
  latest_encrypted_backup, latest_physical_backup,
  xpub, external_public_descriptor, internal_public_descriptor,
  signer, signer_device, is_default, label, synced_at, birthday
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
            [
              id,
              'aabbccdd',
              '11223344',
              1,
              0,
              1680000000,
              1681000000,
              'fixture-xpub',
              'fixture-external',
              'fixture-internal',
              signer.name,
              device?.name,
              1,
              'Existing wallet',
              '2023-11-14T22:13:20.000Z',
              '2020-09-13T12:26:40.000Z',
            ],
          );
          final before = await db
              .customSelect('SELECT * FROM wallet_metadatas')
              .get();
          // Read through the production catalog, then write the same value.
          final entry = await catalog.fetch(id);
          expect(entry, isNotNull);
          if (entry == null) return;
          expect(entry.signer, signer.toEntity());
          expect(entry.signerDevice, device?.toEntity());
          expect(entry.network, Network.bitcoinMainnet);
          expect(entry.scriptType, ScriptType.bip84);
          expect(entry.lastReceiveAddressIndex, 0);
          await catalog.store(entry);
          final after = await db
              .customSelect('SELECT * FROM wallet_metadatas')
              .get();
          expect(after.map((row) => row.data), before.map((row) => row.data));
          expect(await catalog.fetchAll(), [entry]);
          await catalog.delete(id);
          expect(await catalog.fetch(id), isNull);
        },
      );
    }
  }
}
