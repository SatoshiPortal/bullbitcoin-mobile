// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = PayjoinDatabase.forTesting(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // Schema 1 shipped with one switch that gated both sending and receiving
  // between users. After the upgrade both of those keep its value, the
  // exchange switches start on, and existing receivers stay user receivers.
  for (final enabled in [1, 0]) {
    test('migration from v1 to v2 keeps enabled=$enabled for send and '
        'receive', () async {
      final oldPayjoinPoliciesData = <v1.PayjoinPoliciesData>[
        v1.PayjoinPoliciesData(
          id: 1,
          enabled: enabled,
          minimumAmountSat: 12345,
          sessionLifetimeSeconds: 3600,
        ),
      ];
      final expectedNewPayjoinPoliciesData = <v2.PayjoinPoliciesData>[
        v2.PayjoinPoliciesData(
          id: 1,
          enabled: enabled,
          sendEnabled: enabled,
          buyEnabled: 1,
          sellEnabled: 1,
          minimumAmountSat: 12345,
          sessionLifetimeSeconds: 3600,
        ),
      ];

      final oldPayjoinReceiversData = <v1.PayjoinReceiversData>[
        const v1.PayjoinReceiversData(
          id: 'receiver-1',
          address: 'bc1qexample',
          isTestnet: 0,
          receiver: '[]',
          walletId: 'wallet-1',
          pjUri: 'bitcoin:bc1qexample?pj=https://payjo.in/abc',
          maxFeeRateSatPerVb: 20,
          createdAt: 1700000000,
          expireAfterSec: 86400,
          isExpired: 0,
          isCompleted: 0,
          isAborted: 0,
        ),
      ];
      final expectedNewPayjoinReceiversData = <v2.PayjoinReceiversData>[
        const v2.PayjoinReceiversData(
          id: 'receiver-1',
          address: 'bc1qexample',
          isTestnet: 0,
          receiver: '[]',
          walletId: 'wallet-1',
          pjUri: 'bitcoin:bc1qexample?pj=https://payjo.in/abc',
          maxFeeRateSatPerVb: 20,
          createdAt: 1700000000,
          expireAfterSec: 86400,
          isExpired: 0,
          isCompleted: 0,
          isAborted: 0,
          isTrade: 0,
        ),
      ];

      final oldPayjoinSendersData = <v1.PayjoinSendersData>[];
      final expectedNewPayjoinSendersData = <v2.PayjoinSendersData>[];

      final oldPayjoinMigrationsData = <v1.PayjoinMigrationsData>[];
      final expectedNewPayjoinMigrationsData = <v2.PayjoinMigrationsData>[];

      await verifier.testWithDataIntegrity(
        oldVersion: 1,
        newVersion: 2,
        createOld: v1.DatabaseAtV1.new,
        createNew: v2.DatabaseAtV2.new,
        openTestedDatabase: PayjoinDatabase.forTesting,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.payjoinSenders, oldPayjoinSendersData);
          batch.insertAll(oldDb.payjoinReceivers, oldPayjoinReceiversData);
          batch.insertAll(oldDb.payjoinPolicies, oldPayjoinPoliciesData);
          batch.insertAll(oldDb.payjoinMigrations, oldPayjoinMigrationsData);
        },
        validateItems: (newDb) async {
          expect(
            expectedNewPayjoinSendersData,
            await newDb.select(newDb.payjoinSenders).get(),
          );
          expect(
            expectedNewPayjoinReceiversData,
            await newDb.select(newDb.payjoinReceivers).get(),
          );
          expect(
            expectedNewPayjoinPoliciesData,
            await newDb.select(newDb.payjoinPolicies).get(),
          );
          expect(
            expectedNewPayjoinMigrationsData,
            await newDb.select(newDb.payjoinMigrations).get(),
          );
        },
      );
    });
  }

  const insertSender =
      'INSERT INTO payjoin_senders '
      '(uri, is_testnet, sender, wallet_id, original_psbt, original_tx_id, '
      'amount_sat, created_at, expire_after_sec, proposal_psbt, tx_id, '
      'is_expired, is_completed, is_aborted) '
      "VALUES (?, 0, '[]', 'wallet-1', 'cHNidP8=', 'original-tx', 50000, "
      '1700000000, 86400, ?, ?, ?, ?, ?)';

  Future<void> seedSenders(v2.DatabaseAtV2 old) async {
    for (final (uri, proposal, expired, completed, aborted) in [
      ('unfinished-with-proposal', 'cHNidP8=', 0, 0, 0),
      ('unfinished-without-proposal', null, 0, 0, 0),
      ('expired', 'cHNidP8=', 1, 0, 0),
      ('completed', 'cHNidP8=', 0, 1, 0),
      ('aborted', null, 0, 0, 1),
    ]) {
      await old.customStatement(insertSender, [
        uri,
        proposal,
        if (proposal == null) null else 'payjoin-tx',
        expired,
        completed,
        aborted,
      ]);
    }
  }

  Future<Map<String, int>> evidenceByUri(PayjoinDatabase db) async => {
    for (final row in await db.select(db.payjoinSenders).get())
      row.uri: row.hasNetworkEvidence ? 1 : 0,
  };

  // Schema 2 kept no trace of a payment that went out without a recorded
  // outcome, so an unfinished sender cannot be told apart from one that never
  // attempted: it must migrate as holding evidence, never as free to release.
  test(
    'migration from v2 to v3 assumes evidence for unfinished senders',
    () async {
      final schema = await verifier.schemaAt(2);
      final old = v2.DatabaseAtV2(schema.newConnection());
      await seedSenders(old);
      await old.close();

      final db = PayjoinDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 3);

      expect(await evidenceByUri(db), {
        'unfinished-with-proposal': 1,
        'unfinished-without-proposal': 1,
        'expired': 0,
        'completed': 0,
        'aborted': 0,
      });
      final kept =
          await (db.select(db.payjoinSenders)
                ..where((row) => row.uri.equals('unfinished-with-proposal')))
              .getSingle();
      expect(kept.proposalPsbt, 'cHNidP8=');
      expect(kept.txId, 'payjoin-tx');
      expect(kept.originalTxId, 'original-tx');
      await db.close();
    },
  );

  test('re-running the v2 to v3 step never backfills again', () async {
    final schema = await verifier.schemaAt(2);
    final old = v2.DatabaseAtV2(schema.newConnection());
    await seedSenders(old);
    await old.close();
    final first = PayjoinDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(first, 3);
    // What a session created after the upgrade, or a withdrawn attempt, holds.
    await first.customStatement(
      'UPDATE payjoin_senders SET has_network_evidence = 0',
    );
    await first.customStatement('PRAGMA user_version = 2');
    await first.close();

    final second = PayjoinDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(second, 3);
    expect((await evidenceByUri(second)).values, everyElement(0));
    await second.close();
  });

  test('a second connection migrating at the same time opens safely', () async {
    final directory = await Directory.systemTemp.createTemp('payjoin-v3-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/payjoin.sqlite';
    final old = v2.DatabaseAtV2(
      NativeDatabase(
        File(path),
        setup: (db) => db.execute('PRAGMA journal_mode = WAL;'),
      ),
    );
    await seedSenders(old);
    await old.close();

    // The first migrator, stopped inside its step: column added and backfilled
    // but not committed, version still 2 for everyone else.
    final first = sqlite3.open(path);
    first.execute('PRAGMA busy_timeout = 2000;');
    first.execute('BEGIN IMMEDIATE;');
    first.execute(
      'ALTER TABLE payjoin_senders ADD COLUMN has_network_evidence INTEGER '
      'NOT NULL DEFAULT 0 CHECK (has_network_evidence IN (0, 1));',
    );
    first.execute(
      'UPDATE payjoin_senders SET has_network_evidence = 1 '
      'WHERE is_expired = 0 AND is_completed = 0 AND is_aborted = 0;',
    );

    final second = PayjoinDatabase.open(path);
    final opened = evidenceByUri(second);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    first.execute('PRAGMA user_version = 3;');
    first.execute('COMMIT;');
    first.dispose();

    expect(await opened, {
      'unfinished-with-proposal': 1,
      'unfinished-without-proposal': 1,
      'expired': 0,
      'completed': 0,
      'aborted': 0,
    });
    await second.close();
  });
}
