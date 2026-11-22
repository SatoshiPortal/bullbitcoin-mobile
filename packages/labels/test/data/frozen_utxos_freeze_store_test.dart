import 'dart:io';

import 'package:labels/frozen_utxos_table.drift.dart';
import 'package:labels/storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import 'package:sync/testing.dart';

import '../support/labels_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LabelsTestDatabase db;
  late FrozenUtxosFreezeStore store;
  late Directory dir;

  setUp(() {
    db = LabelsTestDatabase(NativeDatabase.memory());
    store = FrozenUtxosFreezeStore(database: db);
    dir = Directory.systemTemp.createTempSync('frozen-utxos-');
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  final a = 'a' * 64;
  final b = 'b' * 64;
  FrozenOutpoint row(String txId, int vout, String origin) =>
      FrozenOutpoint((txId: txId, vout: vout), origin: origin);

  T ok<T>(Result<T, SyncFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => fail('Unexpected ${failure.logCode}'),
  };

  Future<void> insert(String walletId, String txId, int vout) => db
      .into(db.frozenUtxos)
      .insert(
        FrozenUtxosCompanion.insert(walletId: walletId, txId: txId, vout: vout),
      );

  Future<Set<FrozenOutpoint>> table() async => {
    for (final r in await db.select(db.frozenUtxos).get())
      row(r.txId, r.vout, r.walletId),
  };

  test('sync lists every row of the labels table', () async {
    await insert('wpkh([0f36572d/84h/1h/0h])', a, 0);
    await insert('tr([0f36572d/86h/1h/0h])', a, 0);
    await insert('', b, 1);
    final sync = freezesOnlySync(dir.path, freezes: store);
    try {
      final listed = switch (await sync.coins.listFrozen()) {
        Ok(:final value) => value.toSet(),
        Err(:final failure) => fail(failure.logCode),
      };
      expect(listed, {
        row(a, 0, 'wpkh([0f36572d/84h/1h/0h])'),
        row(a, 0, 'tr([0f36572d/86h/1h/0h])'),
        row(b, 1, ''),
      });
    } finally {
      await sync.close();
    }
  });

  test('sync freezes and unfreezes in the labels table', () async {
    final sync = freezesOnlySync(dir.path, freezes: store);
    try {
      ok(await sync.coins.freeze((txId: a, vout: 0), origin: 'one'));
      ok(await sync.coins.freeze((txId: a, vout: 0), origin: ''));
      ok(await sync.coins.freeze((txId: b, vout: 1), origin: 'one'));
      expect(await table(), {
        row(a, 0, 'one'),
        row(a, 0, ''),
        row(b, 1, 'one'),
      });

      // An unfreeze lifts every origin of the outpoint, and only it.
      ok(await sync.coins.unfreeze((txId: a, vout: 0)));
      expect(await table(), {row(b, 1, 'one')});
    } finally {
      await sync.close();
    }
  });

  test('a freeze already stored is kept as it is', () async {
    await insert('one', a, 0);

    ok(await store.freeze([row(a, 0, 'one'), row(a, 0, 'two')]));

    expect(await table(), {row(a, 0, 'one'), row(a, 0, 'two')});
  });

  test('an unreadable database is a failure, never an empty table', () async {
    final file = File('${dir.path}/corrupt.sqlite')
      ..writeAsStringSync('not a database ' * 100);
    final corrupt = LabelsTestDatabase(NativeDatabase(file));
    try {
      final broken = FrozenUtxosFreezeStore(database: corrupt);
      expect(
        await broken.readAll(),
        isA<Err<List<FrozenOutpoint>, SyncFailure>>(),
      );
      expect(
        await broken.freeze([row(a, 0, '')]),
        isA<Err<void, SyncFailure>>(),
      );
      expect(
        await broken.unfreeze([(txId: a, vout: 0)]),
        isA<Err<void, SyncFailure>>(),
      );
    } finally {
      await corrupt.close();
    }
  });
}
