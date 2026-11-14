import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';
import 'package:sync/src/data/datasources/revision_store_datasource.dart';
import 'package:sync/src/data/sqlite_wallet_revision_reader.dart';

void main() {
  test(
    'opening current metadata does not acquire a writer transaction',
    () async {
      final directory = Directory.systemTemp.createTempSync('revision-open-');
      final path = '${directory.path}/revisions.sqlite';
      final initial = RevisionStoreDatasource.openForeground(path);
      final writer = sqlite3.open(path);
      RevisionStoreDatasource? reader;
      try {
        writer.execute('BEGIN IMMEDIATE');
        reader = RevisionStoreDatasource.openExisting(path);
        expect(reader, isNotNull);
      } finally {
        writer.dispose();
        reader?.close();
        initial.close();
        directory.deleteSync(recursive: true);
      }
    },
  );

  test(
    'metadata finish commits while another connection holds a read',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'revision-concurrent-',
      );
      final path = '${directory.path}/revisions.sqlite';
      final store = RevisionStoreDatasource.openForeground(path);
      final reader = SqliteWalletRevisionReader(store);
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
          (await reader.read(key)
                  as Ok<WalletRevisionState, TransactionSyncFailure>)
              .value
              .stamp
              .revision,
          2,
        );
      } finally {
        observer.dispose();
        await reader.close();
        store.close();
        directory.deleteSync(recursive: true);
      }
    },
  );

  test(
    'initialization marker is committed with create load repair and deletion',
    () async {
      final directory = Directory.systemTemp.createTempSync('revision-schema-');
      final path = '${directory.path}/revisions.sqlite';
      final store = RevisionStoreDatasource.openForeground(path);
      final reader = SqliteWalletRevisionReader(store);
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
          store.begin(key, intent);
          final committed = store.finish(key);
          final expected = intent == WriteIntent.delete
              ? 0
              : writerSchemaVersion;
          expect(committed.initializedSchema, expected);
          expect(
            (await reader.read(key)
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
        await reader.close();
        store.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}
