import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema_v15.dart' as v15;

void main() {
  test(
    'published schema 15 wallets default to Electrum without losing metadata',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bull_source_v16',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/wallet.sqlite');
      final old = v15.DatabaseAtV15(NativeDatabase(file));
      await old.customStatement('''
      INSERT INTO wallet_metadatas (
        id, master_fingerprint, xpub_fingerprint, is_encrypted_vault_tested,
        is_physical_backup_tested, xpub, external_public_descriptor,
        internal_public_descriptor, signer, is_default, label, birthday
      ) VALUES (
        'wpkh([deadbeef/84h/0h/0h])', 'deadbeef', 'deadbeef', 1, 1,
        'public', 'wpkh(public/0/*)', 'wpkh(public/1/*)', 'none', 0,
        'Savings', '2020-03-01T23:30:00.000Z'
      )
    ''');
      final before =
          (await old.customSelect('SELECT * FROM wallet_metadatas').get())
              .single
              .data;
      await old.close();

      final current = SqliteDatabase(NativeDatabase(file));
      addTearDown(current.close);
      final after =
          (await current.customSelect('SELECT * FROM wallet_metadatas').get())
              .single
              .data;
      expect(after['bitcoin_sync_source'], 'electrum');
      expect(Map.of(after)..remove('bitcoin_sync_source'), before);
      await current.validateDatabaseSchema();
      expect(
        (await current.customSelect('PRAGMA user_version').get()).single
            .read<int>('user_version'),
        16,
      );
    },
  );
}
