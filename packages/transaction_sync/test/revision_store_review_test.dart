import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/src/write/revision_store.dart';

void main() {
  test(
    'metadata finish commits while another connection holds a read',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'revision-concurrent-',
      );
      final path = '${directory.path}/revisions.sqlite';
      final store = RevisionStore(path);
      final key = WalletKey(id: 'fixture', network: BitcoinNetwork.testnet);
      final observer = sqlite3.open(path);
      try {
        store.begin(key, WriteIntent.create);
        store.finish(key);
        store.begin(key, WriteIntent.load);
        observer.execute('BEGIN');
        expect(
          observer.select('SELECT revision FROM revisions').single['revision'],
          1,
        );
        store.finish(key);
        expect(
          observer.select('SELECT revision FROM revisions').single['revision'],
          1,
        );
        observer.execute('COMMIT');
        expect(
          observer.select('SELECT revision FROM revisions').single['revision'],
          2,
        );
        expect(
          (await store.read(key)
                  as Ok<WalletRevisionState, TransactionSyncFailure>)
              .value
              .stamp
              .revision,
          2,
        );
      } finally {
        observer.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      }
    },
  );

  test(
    'initialization marker is committed with create load repair and deletion',
    () async {
      final directory = Directory.systemTemp.createTempSync('revision-schema-');
      final path = '${directory.path}/revisions.sqlite';
      final store = RevisionStore(path);
      final key = WalletKey(id: 'fixture', network: BitcoinNetwork.testnet);
      final observer = sqlite3.open(path);
      try {
        expect(
          observer
              .select('PRAGMA table_info(revisions)')
              .map((row) => row['name']),
          contains('initialized_schema'),
        );
        for (final intent in [
          WriteIntent.create,
          WriteIntent.load,
          WriteIntent.repair,
          WriteIntent.delete,
        ]) {
          final published = store.watch(key).first;
          store.begin(key, intent);
          store.finish(key);
          final expected = intent == WriteIntent.delete
              ? 0
              : writerSchemaVersion;
          expect((await published).initializedSchema, expected);
          expect(
            (await store.read(key)
                    as Ok<WalletRevisionState, TransactionSyncFailure>)
                .value
                .initializedSchema,
            expected,
          );
          expect(
            observer
                .select('SELECT initialized_schema FROM revisions')
                .single['initialized_schema'],
            intent == WriteIntent.delete ? 0 : 1,
          );
        }
      } finally {
        observer.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}
