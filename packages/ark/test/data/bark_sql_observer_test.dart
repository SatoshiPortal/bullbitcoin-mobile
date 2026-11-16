import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ark/ark.dart';
import 'package:ark/src/data/exit_archive/bark_sql_schema.dart';
import 'package:ark/src/data/exit_archive/ark_exit_archive.dart';
import 'package:ark/src/data/exit_archive/bark_sql_observer.dart';
import 'package:ark/src/data/exit_archive/bark_sql_observation.dart';
import 'package:ark/src/data/exit_archive/sqlite_exit_archive.dart';
import 'package:primitives/primitives.dart';

import '../support/bark_sql_fixture.dart';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  test('pure guard accepts exact source schema42 and leaves caller transaction intact', () {
    final db = sqlite3.openInMemory();
    try {
      seed(db);
      db.execute('BEGIN');
      expect(schema.validate(db), isA<Ok>());
      db.execute('ROLLBACK');
      expect(db.select('SELECT count(*) AS n FROM migrations').single['n'], 1);
    } finally {
      db.close();
    }
  });
  test('same index_list cannot hide changed UNIQUE columns', () {
    final db = sqlite3.openInMemory();
    try {
      seed(db);
      final before = db
          .select('PRAGMA index_list(bark_vtxo_key)')
          .map((r) => r.values.toList())
          .toList();
      db.execute('DROP TABLE bark_vtxo_key');
      db.execute(
        'CREATE TABLE bark_vtxo_key(public_key TEXT NOT NULL PRIMARY KEY,idx INTEGER NOT NULL,UNIQUE(idx,public_key))',
      );
      expect(
        db
            .select('PRAGMA index_list(bark_vtxo_key)')
            .map((r) => r.values.toList()),
        before,
      );
      expect(schema.validate(db), isA<Err>());
    } finally {
      db.close();
    }
  });
  group('source observation and opaque retention', () {
    late Directory temp;
    late Database writer;
    late SqliteBarkObserver observer;
    late SqliteExitArchive archive;
    setUp(() {
      temp = Directory.systemTemp.createTempSync('ark-sql-observer-');
      writer = sqlite3.open('${temp.path}/source');
      seed(writer);
      writer.execute('PRAGMA journal_mode=WAL');
      observer = SqliteBarkObserver(
        sourcePath: '${temp.path}/source',
        schema: schema,
      );
      archive = got(
        SqliteExitArchive.open(
          '${temp.path}/archive',
          account,
          create: true,
          sqlSchema: schema,
        ),
      );
    });
    tearDown(() async {
      await observer.close();
      await archive.close();
      writer.close();
      temp.deleteSync(recursive: true);
    });
    Future<BarkSqlObservation> observe() async => got(await observer.read());
    List<Row> opaque() {
      final db = sqlite3.open('${temp.path}/archive');
      try {
        return db
            .select('SELECT * FROM opaque_sql_rows ORDER BY digest')
            .toList();
      } finally {
        db.close();
      }
    }

    test(
      'all nine typed queries return immutable opaque data, not Full',
      () async {
        writer.execute(
          'INSERT INTO bark_vtxo(id,raw_bare,raw_genesis,amount_sat) VALUES(?,?,?,?)',
          [
            'v',
            Uint8List.fromList([1, 2]),
            Uint8List.fromList([3]),
            1000,
          ],
        );
        writer.execute(
          'INSERT INTO bark_wallet_action_checkpoint(id,payload) VALUES(?,?)',
          [
            'action',
            Uint8List.fromList([4, 5]),
          ],
        );
        final observed = await observe();
        final row = observed.rows.singleWhere(
          (r) => r.sourceTable == 'bark_vtxo',
        );
        schema.checkRow(row);
        final decoded = jsonDecode(row.payload) as List;
        expect((decoded[8] as List)[1], [
          'raw_bare',
          ['blob', '0102'],
        ]);
        expect((decoded[8] as List)[2], [
          'raw_genesis',
          ['blob', '03'],
        ]);
        expect(() => observed.rows.clear(), throwsUnsupportedError);
        final mutable = observed.rows.toList();
        final copied = BarkSqlObservation(
          account,
          observed.sourceToken,
          observed.observedAtUTC,
          mutable,
        );
        mutable.clear();
        expect(copied.rows.length, observed.rows.length);
        got(await archive.appendSqlObservation(observed));
        final state = got(await archive.read());
        expect(state.proofs, isEmpty);
        expect(state.heads, isEmpty);
        expect(state.state, ArkExitCaptureState.incomplete);
        expect(state.acknowledgedThrough, 0);
        expect(
          state.issues,
          contains(ArkExitCaptureIssue.nativeCoverageUnavailable),
        );
      },
    );
    test(
      'data_version is retained-connection local and sees unqueried commits',
      () async {
        final first = await observe(), unchanged = await observe();
        expect(unchanged.sourceToken, first.sourceToken);
        writer.execute(
          "INSERT INTO bark_mailbox_checkpoint(id,checkpoint,updated_at) VALUES(1,2,'now')",
        );
        final changed = await observe();
        expect(changed.sourceToken.epochConn, first.sourceToken.epochConn);
        expect(
          changed.sourceToken.dataVersion,
          isNot(first.sourceToken.dataVersion),
        );
        expect(
          changed.rows.map((r) => r.digest),
          first.rows.map((r) => r.digest),
        );
      },
    );
    test(
      'WAL uncommitted row is excluded and next committed pass includes it',
      () async {
        writer.execute('BEGIN IMMEDIATE');
        writer.execute("INSERT INTO bark_vtxo(id) VALUES('pending')");
        final before = await observe();
        expect(before.rows.where((r) => r.sourceTable == 'bark_vtxo'), isEmpty);
        writer.execute('COMMIT');
        final after = await observe();
        expect(
          after.rows.where((r) => r.sourceTable == 'bark_vtxo'),
          hasLength(1),
        );
        expect(
          after.sourceToken.dataVersion,
          isNot(before.sourceToken.dataVersion),
        );
      },
    );
    test(
      'DATETIME is text/null and preimage cells remain opaque strings',
      () async {
        writer.execute(
          'INSERT INTO bark_pending_lightning_receive(payment_hash,preimage,invoice,htlc_recv_cltv_delta,finished_at) VALUES(?,?,?,?,?)',
          [
            'synthetic-hash',
            'synthetic-preimage',
            'synthetic-invoice',
            10,
            '2026-11-16 00:00:00',
          ],
        );
        final row = (await observe()).rows.singleWhere(
          (r) => r.sourceTable == 'bark_pending_lightning_receive',
        );
        expect(((jsonDecode(row.payload) as List)[8] as List).last, [
          'finished_at',
          ['text', '2026-11-16 00:00:00'],
        ]);
        schema.checkRow(row);
        expect(row.toString(), isNot(contains('synthetic-preimage')));
      },
    );
    for (final corruption in [
      'version',
      'identity',
      'cell',
      'null-key',
      'unique-index',
    ]) {
      test(
        'each pass refuses source $corruption and retains previous opaque evidence',
        () async {
          final initial = await observe();
          got(await archive.appendSqlObservation(initial));
          final old = opaque().map((r) => r['digest']).toSet();
          switch (corruption) {
            case 'version':
              writer.execute('INSERT INTO migrations(value) VALUES(43)');
            case 'identity':
              writer.execute(
                "UPDATE bark_properties SET fingerprint='ffffffff'",
              );
            case 'cell':
              writer.execute(
                "INSERT INTO bark_vtxo(id,raw_bare) VALUES('bad','text-not-blob')",
              );
            case 'null-key':
              writer.execute('INSERT INTO bark_vtxo(id) VALUES(NULL)');
            case 'unique-index':
              writer.execute('DROP TABLE bark_vtxo_key');
              writer.execute(
                'CREATE TABLE bark_vtxo_key(public_key TEXT NOT NULL PRIMARY KEY,idx INTEGER NOT NULL,UNIQUE(idx,public_key))',
              );
          }
          expect(await observer.read(), isA<Err>());
          expect(opaque().map((r) => r['digest']).toSet(), old);
        },
      );
    }
    test(
      'row and byte admission limits refuse the whole observation',
      () async {
        writer.execute(
          "INSERT INTO bark_vtxo(id,raw_bare) VALUES('v',zeroblob(20))",
        );
        for (final limited in [
          SqliteBarkObserver(
            sourcePath: '${temp.path}/source',
            schema: schema,
            maxRows: 1,
          ),
          SqliteBarkObserver(
            sourcePath: '${temp.path}/source',
            schema: schema,
            maxBytes: 10,
          ),
        ]) {
          expect(await limited.read(), isA<Err>());
          await limited.close();
        }
        expect((await observe()).rows, hasLength(2));
      },
    );
    test('row versions append, duplicate and old-version return dedup, absence retains', () async {
      writer.execute("INSERT INTO bark_vtxo(id,raw_bare) VALUES('v',x'01')");
      final first = await observe();
      expect(got(await archive.appendSqlObservation(first)), isTrue);
      final timestamp = opaque().first['observed_at_utc'];
      expect(got(await archive.appendSqlObservation(await observe())), isFalse);
      expect(opaque().first['observed_at_utc'], timestamp);
      writer.execute("UPDATE bark_vtxo SET raw_bare=x'02'");
      expect(got(await archive.appendSqlObservation(await observe())), isTrue);
      writer.execute("UPDATE bark_vtxo SET raw_bare=x'01'");
      expect(got(await archive.appendSqlObservation(await observe())), isFalse);
      writer.execute('DELETE FROM bark_vtxo');
      expect(got(await archive.appendSqlObservation(await observe())), isFalse);
      expect(
        opaque().where((r) => r['source_table'] == 'bark_vtxo'),
        hasLength(2),
      );
      await archive.close();
      archive = got(
        SqliteExitArchive.open(
          '${temp.path}/archive',
          account,
          create: false,
          sqlSchema: schema,
        ),
      );
      expect(got(await archive.read()).proofs, isEmpty);
      expect(
        opaque().where((r) => r['source_table'] == 'bark_vtxo'),
        hasLength(2),
      );
    });
    test('foreign configured identity, SQL keys and payload corruption never repair', () async {
      final observation = await observe();
      got(await archive.appendSqlObservation(observation));
      final db = sqlite3.open('${temp.path}/archive');
      db.execute("UPDATE opaque_sql_rows SET row_key='wrong-key'");
      db.close();
      expect(await archive.read(), isA<Err>());
      expect(await archive.appendSqlObservation(observation), isA<Err>());
      expect(opaque().single['row_key'], 'wrong-key');
      await archive.close();
      expect(
        SqliteExitArchive.open(
          '${temp.path}/archive',
          account,
          create: false,
          sqlSchema: schema,
        ),
        isA<Err>(),
      );
    });
    test('last metadata write failure rolls back all new rows while old evidence survives', () async {
      got(await archive.appendSqlObservation(await observe()));
      final old = opaque().map((r) => r['digest']).toSet();
      writer.execute("INSERT INTO bark_vtxo(id,raw_bare) VALUES('v',x'01')");
      writer.execute(
        "INSERT INTO bark_vtxo_key(public_key,idx) VALUES('key',9)",
      );
      final db = sqlite3.open('${temp.path}/archive');
      db.execute(
        "CREATE TRIGGER reject_opaque_finish BEFORE UPDATE ON archive_meta BEGIN SELECT RAISE(ABORT,'injected'); END",
      );
      db.close();
      expect(await archive.appendSqlObservation(await observe()), isA<Err>());
      expect(opaque().map((r) => r['digest']).toSet(), old);
      await archive.close();
      archive = got(
        SqliteExitArchive.open(
          '${temp.path}/archive',
          account,
          create: false,
          sqlSchema: schema,
        ),
      );
      expect(opaque().map((r) => r['digest']).toSet(), old);
      expect(got(await archive.read()).acknowledgedThrough, 0);
    });
    test('missing source, non-regtest and closed observer never create a source DB', () async {
      final missing = '${temp.path}/missing';
      final absent = SqliteBarkObserver(sourcePath: missing, schema: schema);
      expect(await absent.read(), isA<Err>());
      await absent.close();
      final unsupported = SqliteBarkObserver(
        sourcePath: missing,
        schema: BarkSqlSchema(
          ArkAccountId(
            parent: account.parent,
            network: BitcoinNetwork.mainnet,
            serverIdentity: 'declined',
          ),
          schema.expectedNativeFingerprint,
          schema.expectedServerPubkey,
        ),
      );
      expect(await unsupported.read(), isA<Err>());
      await unsupported.close();
      expect(File(missing).existsSync(), isFalse);
      await observer.close();
      expect(await observer.read(), isA<Err>());
    });
  });
}
