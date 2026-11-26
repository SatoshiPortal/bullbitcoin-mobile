import 'dart:convert';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_sql.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../support/bark_sql_fixture.dart';

/// Synthetic parser/lifecycle controls; not the required real populated fixture.
void main() {
  late Directory temp;
  late Database writer;
  late String path;
  late ArkSqlExitRepository reader;
  final parent = 'a' * 64, child = 'b' * 64, id = '${'c' * 64}:0';
  final block = {'height': 10, 'hash': 'd' * 64};
  final origins = [
    {'type': 'wallet', 'confirmed_in': null},
    {'type': 'wallet', 'confirmed_in': block},
    {'type': 'mempool'},
    {'type': 'block', 'confirmed_in': block},
  ];
  final statuses = [
    {'type': 'verify-inputs'},
    {
      'type': 'awaiting-input-confirmation',
      'txids': [parent],
    },
    {'type': 'awaiting-cpfp-broadcast'},
    {
      'type': 'awaiting-confirmation',
      'child_txid': child,
      'origin': origins.first,
    },
    {
      'type': 'confirmed',
      'child_txid': child,
      'origin': origins.last,
      'block': block,
    },
  ];
  final states = [
    {'type': 'start'},
    {
      'type': 'processing',
      'transactions': [
        for (final status in statuses) {'txid': parent, 'status': status},
      ],
    },
    {
      'type': 'awaiting-delta',
      'confirmed_block': block,
      'claimable_height': 20,
    },
    {'type': 'claimable', 'claimable_since': block, 'last_scanned_block': null},
    {
      'type': 'claim-in-progress',
      'claimable_since': block,
      'claim_txid': child,
    },
    {'type': 'claimed', 'txid': child, 'block': block},
    {'type': 'vtxo-already-spent'},
    {
      'type': 'vtxo-swept',
      'spent_inputs': [id],
    },
    {'type': 'canceled'},
  ];
  ArkSqlExitRepository build({String? fingerprint}) =>
      createArkSqlExitRepository(
        databasePath: path,
        account: account,
        expectedNativeFingerprint:
            fingerprint ?? schema.expectedNativeFingerprint,
        expectedServerPubkey: schema.expectedServerPubkey,
      );
  void state(Map<String, Object?> value) => writer.execute(
    'INSERT OR REPLACE INTO bark_exit_states(vtxo_id,state,history) VALUES(?,?,?)',
    [id, jsonEncode(value), 'unread history is not validated'],
  );
  T found<T>(Result<ArkSqlRead<T>, ArkWalletFailure> result) {
    expect(result, isA<Ok<ArkSqlRead<T>, ArkWalletFailure>>());
    final value = got(result);
    expect(value, isA<ArkSqlFound<T>>());
    return (value as ArkSqlFound<T>).value;
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync('bark-sql-read-');
    path = '${temp.path}/source.sqlite';
    writer = sqlite3.open(path);
    seed(writer);
    reader = build();
  });
  tearDown(() {
    writer.close();
    temp.deleteSync(recursive: true);
  });

  test(
    'index_xinfo detects changed unique columns despite identical index_list',
    () async {
      final before = writer
          .select('PRAGMA index_list(bark_vtxo_key)')
          .map((r) => r.values.toList())
          .toList();
      writer.execute('DROP TABLE bark_vtxo_key');
      writer.execute(
        'CREATE TABLE bark_vtxo_key(public_key TEXT NOT NULL PRIMARY KEY,idx INTEGER NOT NULL,UNIQUE(idx,public_key))',
      );
      expect(
        writer
            .select('PRAGMA index_list(bark_vtxo_key)')
            .map((r) => r.values.toList())
            .toList(),
        before,
      );
      expect(await reader.readVtxo(vtxoId: id), isA<Err>());
    },
  );
  test(
    'REAL42 cell with pinned INTEGER declaration refuses before NotFound',
    () async {
      final file = '${temp.path}/real-marker.sqlite';
      final db = sqlite3.open(file);
      try {
        db.execute(
          sourceFixture().replaceFirst(
            'value INTEGER NOT NULL',
            'value BLOB NOT NULL',
          ),
        );
        db.execute('INSERT INTO migrations(value) VALUES(?)', [42.0]);
        db.execute(
          'INSERT INTO bark_properties(id,network,fingerprint,server_pubkey) VALUES(?,?,?,?)',
          [
            '1',
            'regtest',
            schema.expectedNativeFingerprint,
            schema.expectedServerPubkey,
          ],
        );
        db.execute('PRAGMA writable_schema=ON');
        db.execute(
          "UPDATE sqlite_schema SET sql=replace(sql,'value BLOB NOT NULL','value INTEGER NOT NULL') WHERE name='migrations'",
        );
        db.execute('PRAGMA writable_schema=OFF');
        final version = db.select('PRAGMA schema_version').single.values.single;
        if (version is! int) fail('Invalid synthetic schema counter');
        db.execute('PRAGMA schema_version=${version + 1}');
        expect(
          db
              .select('SELECT typeof(value) AS kind FROM migrations')
              .single['kind'],
          'real',
        );
      } finally {
        db.close();
      }
      final corrupt = createArkSqlExitRepository(
        databasePath: file,
        account: account,
        expectedNativeFingerprint: schema.expectedNativeFingerprint,
        expectedServerPubkey: schema.expectedServerPubkey,
      );
      expect(await corrupt.readVtxo(vtxoId: id), isA<Err>());
    },
  );
  for (var index = 0; index < statuses.length; index++) {
    for (final field in statuses[index].keys.where((key) => key != 'type')) {
      test(
        'required nested status field $index/$field cannot be discarded',
        () async {
          final bad = {...statuses[index]}..remove(field);
          state({
            'type': 'processing',
            'tip_height': 10,
            'transactions': [
              {'txid': parent, 'status': bad},
            ],
          });
          expect(await reader.readExitState(vtxoId: id), isA<Err>());
        },
      );
    }
  }
  test(
    'parse refusal releases its readonly transaction before returning Err',
    () async {
      writer.execute(
        'INSERT INTO bark_exit_states(vtxo_id,state,history) VALUES(?,?,?)',
        [id, '{', '[]'],
      );
      expect(await reader.readExitState(vtxoId: id), isA<Err>());
      writer.execute('BEGIN EXCLUSIVE');
      writer.execute('ROLLBACK');
    },
  );
  test('constructor creates nothing and absent DB is Err, distinct from guarded NotFound', () async {
    final other = '${temp.path}/missing';
    final missing = createArkSqlExitRepository(
      databasePath: other,
      account: account,
      expectedNativeFingerprint: schema.expectedNativeFingerprint,
      expectedServerPubkey: schema.expectedServerPubkey,
    );
    expect(File(other).existsSync(), isFalse);
    expect(await missing.readVtxo(vtxoId: id), isA<Err>());
    expect(File(other).existsSync(), isFalse);
    expect(
      got(await reader.readVtxo(vtxoId: id)),
      isA<ArkSqlNotFound<ArkSqlVtxoComponents>>(),
    );
    expect(
      got(await reader.readExitState(vtxoId: id)),
      isA<ArkSqlNotFound<ArkSqlExitState>>(),
    );
    expect(
      got(await reader.readExitChild(parentTxid: parent)),
      isA<ArkSqlNotFound<ArkSqlExitChild>>(),
    );
  });
  for (final change in ['version', 'missing', 'layout', 'identity']) {
    test('$change guard fails before missing-row lookup', () async {
      switch (change) {
        case 'version':
          writer.execute('INSERT INTO migrations(value) VALUES(43)');
        case 'missing':
          writer.execute('DROP TABLE bark_exit_child_transactions');
        case 'layout':
          writer.execute('ALTER TABLE bark_vtxo_key ADD COLUMN extra TEXT');
        case 'identity':
          reader = build(fingerprint: '87654321');
      }
      expect(await reader.readVtxo(vtxoId: id), isA<Err>());
      expect(await reader.readExitState(vtxoId: id), isA<Err>());
      expect(await reader.readExitChild(parentTxid: parent), isA<Err>());
    });
  }
  for (final bare in [
    null,
    <int>[],
    [1, 2],
  ]) {
    for (final genesis in [
      null,
      <int>[],
      [3, 4],
    ]) {
      test(
        'exact detached nullable components bare=$bare genesis=$genesis',
        () async {
          writer.execute(
            'INSERT INTO bark_vtxo(id,raw_bare,raw_genesis) VALUES(?,?,?)',
            [id, bare, genesis],
          );
          final value = found(await reader.readVtxo(vtxoId: id));
          expect(value.vtxoId, id);
          expect(value.rawBare, bare);
          expect(value.rawGenesis, genesis);
          final storedBare = value.rawBare, storedGenesis = value.rawGenesis;
          if (storedBare != null) {
            expect(() => storedBare.add(9), throwsUnsupportedError);
          }
          if (storedGenesis != null) {
            expect(() => storedGenesis.add(9), throwsUnsupportedError);
          }
          writer.execute(
            "UPDATE bark_vtxo SET raw_bare=x'05',raw_genesis=x'06'",
          );
          expect(value.rawBare, bare);
          expect(value.rawGenesis, genesis);
          expect(found(await reader.readVtxo(vtxoId: id)).rawBare, [5]);
        },
      );
    }
  }
  test(
    'component runtime kinds and byte bounds refuse without a protocol decoder',
    () async {
      writer.execute("INSERT INTO bark_vtxo(id,raw_bare) VALUES(?,'wrong')", [
        id,
      ]);
      expect(await reader.readVtxo(vtxoId: id), isA<Err>());
      writer.execute('UPDATE bark_vtxo SET raw_bare=zeroblob(?)', [
        1024 * 1024 + 1,
      ]);
      expect(await reader.readVtxo(vtxoId: id), isA<Err>());
      writer.execute("UPDATE bark_vtxo SET raw_bare=NULL,raw_genesis='wrong'");
      expect(await reader.readVtxo(vtxoId: id), isA<Err>());
    },
  );
  for (var index = 0; index < states.length; index++) {
    test(
      'pinned exit phase $index validates and projects recorded references only',
      () async {
        state({...states[index], 'tip_height': 10});
        final value = found(await reader.readExitState(vtxoId: id));
        expect(value.phase, ArkSqlExitPhase.values[index]);
        expect(value.vtxoId, id);
        expect(value.transactionRefs.length, index == 1 ? 5 : 0);
        expect(() => value.transactionRefs.clear(), throwsUnsupportedError);
        if (index == 1) {
          expect(
            value.transactionRefs.map((e) => e.phase),
            ArkSqlExitTransactionPhase.values,
          );
          expect(value.transactionRefs.last.parentTxid, parent);
          expect(value.transactionRefs.last.childTxid, child);
        }
      },
    );
    for (final field in [
      'tip_height',
      ...states[index].keys.where((key) => key != 'type'),
    ]) {
      test(
        'required discarded field phase=$index field=$field cannot be absent',
        () async {
          final value = {...states[index], 'tip_height': 10}..remove(field);
          state(value);
          expect(await reader.readExitState(vtxoId: id), isA<Err>());
        },
      );
    }
  }
  for (var index = 0; index < origins.length; index++) {
    test(
      'full child bytes and typed origin $index do not claim consensus validity',
      () async {
        writer.execute(
          'INSERT INTO bark_exit_child_transactions(exit_id,child_tx,tx_origin) VALUES(?,?,?)',
          [
            parent,
            [0, 255, 1],
            jsonEncode(origins[index]),
          ],
        );
        final value = found(await reader.readExitChild(parentTxid: parent));
        expect(value.parentTxid, parent);
        expect(value.transactionBytes, [0, 255, 1]);
        expect(
          value.origin,
          [
            ArkSqlExitChildOrigin.wallet,
            ArkSqlExitChildOrigin.wallet,
            ArkSqlExitChildOrigin.mempool,
            ArkSqlExitChildOrigin.block,
          ][index],
        );
        expect(value.confirmedIn?.height, index == 1 || index == 3 ? 10 : null);
        expect(() => value.transactionBytes[0] = 7, throwsUnsupportedError);
        writer.execute(
          "UPDATE bark_exit_child_transactions SET child_tx=x'03'",
        );
        expect(value.transactionBytes, [0, 255, 1]);
        expect(
          found(await reader.readExitChild(parentTxid: parent))
              .transactionBytes,
          [3],
        );
      },
    );
  }
  for (final payload in [<int>[], 'not-blob', 1]) {
    test('child SQL kind or empty BLOB refuses $payload', () async {
      writer.execute('INSERT INTO bark_exit_child_transactions VALUES(?,?,?)', [
        parent,
        payload,
        jsonEncode(origins.first),
      ]);
      expect(await reader.readExitChild(parentTxid: parent), isA<Err>());
    });
  }
  test('child and UTF8 origin octet bounds checked independently before materialization', () async {
    writer.execute(
      'INSERT INTO bark_exit_child_transactions VALUES(?,zeroblob(?),?)',
      [parent, 1024 * 1024 + 1, jsonEncode(origins.first)],
    );
    expect(await reader.readExitChild(parentTxid: parent), isA<Err>());
    final text = jsonEncode({
      'type': 'mempool',
      'unreturned': 'é' * (600 * 1024),
    });
    writer.execute(
      "UPDATE bark_exit_child_transactions SET child_tx=x'01',tx_origin=?",
      [text],
    );
    final lengths = writer
        .select(
          'SELECT length(tx_origin) AS chars,length(CAST(tx_origin AS BLOB)) AS octets FROM bark_exit_child_transactions',
        )
        .single;
    expect(lengths['chars'] as int, lessThan(1024 * 1024));
    expect(lengths['octets'] as int, greaterThan(1024 * 1024));
    expect(await reader.readExitChild(parentTxid: parent), isA<Err>());
    state({
      'type': 'start',
      'tip_height': 10,
      'unreturned': 'é' * (600 * 1024),
    });
    expect(await reader.readExitState(vtxoId: id), isA<Err>());
  });
  for (final invalid in [
    {'type': 'future', 'tip_height': 10},
    {'type': 'start', 'tip_height': 1.0},
    {
      'type': 'claimed',
      'tip_height': 10,
      'txid': child,
      'block': {'height': 1.0, 'hash': parent},
    },
    {
      'type': 'processing',
      'tip_height': 10,
      'transactions': List.filled(257, {}),
    },
    {
      'type': 'processing',
      'tip_height': 10,
      'transactions': [
        {
          'txid': parent,
          'status': {
            'type': 'confirmed',
            'child_txid': child,
            'origin': origins.last,
          },
        },
      ],
    },
    {
      'type': 'vtxo-swept',
      'tip_height': 10,
      'spent_inputs': [parent],
    },
  ]) {
    test(
      'invalid required JSON payload returns Err ${invalid['type']}',
      () async {
        state(invalid);
        expect(await reader.readExitState(vtxoId: id), isA<Err>());
      },
    );
  }
  for (final invalid in [
    {},
    {'type': 'wallet'},
    {'type': 'block', 'confirmed_in': null},
    {'type': 'mempool', 'confirmed_in': null},
    {'type': 'new'},
  ]) {
    test('invalid origin refuses $invalid', () async {
      writer.execute('INSERT INTO bark_exit_child_transactions VALUES(?,?,?)', [
        parent,
        [1],
        jsonEncode(invalid),
      ]);
      expect(await reader.readExitChild(parentTxid: parent), isA<Err>());
    });
  }
  test('canonical requested IDs cannot become injected SQL or parent/VTXO confusion', () async {
    expect(await reader.readExitChild(parentTxid: id), isA<Err>());
    expect(await reader.readExitState(vtxoId: parent), isA<Err>());
    expect(await reader.readVtxo(vtxoId: "$id' OR 1=1"), isA<Err>());
    expect(await reader.readVtxo(vtxoId: '$parent:4294967296'), isA<Err>());
    expect(await reader.readVtxo(vtxoId: '$parent:00'), isA<Err>());
  });
  test('short readonly snapshots see committed WAL only and preserve source main bytes', () async {
    writer.execute('PRAGMA journal_mode=WAL');
    writer.execute("INSERT INTO bark_vtxo(id,raw_bare) VALUES(?,x'01')", [id]);
    final before = File(path).readAsBytesSync();
    writer.execute('BEGIN IMMEDIATE');
    writer.execute("UPDATE bark_vtxo SET raw_bare=x'02'");
    expect(found(await reader.readVtxo(vtxoId: id)).rawBare, [1]);
    writer.execute('COMMIT');
    expect(found(await reader.readVtxo(vtxoId: id)).rawBare, [2]);
    expect(File(path).readAsBytesSync(), before);
    expect(writer.select('PRAGMA journal_mode').single.values.single, 'wal');
    writer.execute('BEGIN EXCLUSIVE');
    writer.execute('ROLLBACK');
  });
}
