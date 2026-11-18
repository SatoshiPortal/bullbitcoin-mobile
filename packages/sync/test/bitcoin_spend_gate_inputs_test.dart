import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart' show MemoryFreezeStore;
import 'package:sync/write.dart';
import 'package:sync/src/data/datasources/spend_gate_store_datasource.dart';
import 'package:sync/src/data/datasources/revision_store_datasource.dart';
import 'package:sync/src/data/native_store_paths.dart';

import 'support/connections.dart';
import 'support/regtest_wallet.dart';

final class _NoInputReservations implements InputReservationPort {
  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async =>
      const Ok([]);
}

void main() {
  late Directory dir;
  late BitcoinWalletDescriptor wallet;
  late ForegroundStores stores;
  late RevisionStoreDatasource revisions;
  late BitcoinSpendGate gate;
  const txid =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const replacement =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  setUp(() {
    dir = Directory.systemTemp.createTempSync('spend-inputs-');
    wallet = BitcoinWalletDescriptor(
      key: WalletKey(id: 'one', network: BitcoinNetwork.testnet),
      scriptType: ScriptType.bip84,
      origin: 'public-fixture',
      externalDescriptor: 'wpkh(public/one/0)',
      internalDescriptor: 'wpkh(public/one/1)',
    );
    stores = openForeground(
      documentsDirectory: dir.path,
      catalog: SingleWalletCatalog(wallet),
      reservedAddresses: NoReservedAddresses(),
      freezes: MemoryFreezeStore(),
      inputReservations: _NoInputReservations(),
      connections: FixtureConnections(const []),
    );
    revisions = RevisionStoreDatasource.openExisting(
      revisionStorePath(dir.path),
    );
    revisions.begin(wallet.key, WriteIntent.create);
    revisions.finish(wallet.key, initializedDescriptor: wallet);
    gate = stores.spendGate;
  });

  tearDown(() async {
    revisions.close();
    await stores.close();
    dir.deleteSync(recursive: true);
  });

  test('storage retry owns an immutable copy of accepted inputs', () async {
    final db = sqlite3.open(spendGateStorePath(dir.path));
    addTearDown(db.close);
    db.execute(
      "CREATE TRIGGER fail_record BEFORE INSERT ON broadcasts BEGIN SELECT RAISE(FAIL, 'storage unavailable'); END",
    );
    final inputs = <Outpoint>[(txId: 'b' * 64, vout: 7)];
    final admission = await gate.acquire(wallet.key) as BitcoinSpendAdmission;
    expect(admission.accepted(txid, inputs: inputs).durable, isFalse);
    admission.close();
    inputs
      ..clear()
      ..add((txId: 'c' * 64, vout: 8));
    expect(await gate.check(wallet.key), BitcoinSpendStatus.unavailable);
    db.execute('DROP TRIGGER fail_record');
    expect(await gate.check(wallet.key), BitcoinSpendStatus.pending);
    final reopened = SpendGateStoreDatasource.openExisting(
      spendGateStorePath(dir.path),
    );
    try {
      expect(reopened.trackedInputs(wallet)[txid], {'${'b' * 64}:7'});
    } finally {
      reopened.close();
    }
  });

  test('acceptance backfills only NULL and preserves replay metadata', () {
    final store = SpendGateStoreDatasource.openExisting(
      spendGateStorePath(dir.path),
    );
    final inputs = {'${'b' * 64}:7'};
    try {
      store.accepted(wallet, 4, txid);
      store.observed(wallet, 4, {txid});
      store.accepted(wallet, 9, txid, inputs: inputs);
      expect(store.trackedInputs(wallet)[txid], inputs);
      expect(store.isObserved(wallet.key, txid), isTrue);
      expect(store.generationMismatch(wallet.key, 4), isFalse);
      // A repeated acceptance cannot overwrite known inputs, even with a
      // different caller generation, nor erase the positive observation.
      store.accepted(wallet, 10, txid, inputs: {'${'c' * 64}:8'});
      store.accepted(wallet, 11, txid);
      expect(store.trackedInputs(wallet)[txid], inputs);
      expect(store.isObserved(wallet.key, txid), isTrue);
      expect(store.generationMismatch(wallet.key, 4), isFalse);
    } finally {
      store.close();
    }
  });

  test('txid-only and empty-input handoffs remain honest NULL obligations', () {
    final store = SpendGateStoreDatasource.openExisting(
      spendGateStorePath(dir.path),
    );
    try {
      store.accepted(wallet, 1, txid);
      store.accepted(wallet, 1, replacement, inputs: {});
      expect(store.trackedInputs(wallet), {
        txid: <String>{},
        replacement: <String>{},
      });
      expect(store.blocked(wallet), isTrue);
      store.observed(wallet, 1, {});
      expect(store.blocked(wallet), isTrue);
      final db = sqlite3.open(spendGateStorePath(dir.path));
      try {
        expect(
          db.select('SELECT inputs FROM broadcasts').map((r) => r['inputs']),
          everyElement(isNull),
        );
      } finally {
        db.close();
      }
      // Positive observation can recover old or txid-only input evidence.
      store.observed(
        wallet,
        1,
        {txid},
        inputs: {
          txid: {'${'b' * 64}:7'},
        },
      );
      expect(store.trackedInputs(wallet)[txid], {'${'b' * 64}:7'});
      expect(store.isObserved(wallet.key, txid), isTrue);
      expect(store.blocked(wallet), isTrue); // The other unknown remains.
    } finally {
      store.close();
    }
  });

  test('accepted outpoints are canonical and bounded before persistence', () {
    final store = SpendGateStoreDatasource.openExisting(
      spendGateStorePath(dir.path),
    );
    try {
      for (final malformed in [
        '${'b' * 64}:-1',
        '${'b' * 64}:4294967296',
        '${'b' * 64}:01',
        '${'B' * 64}:0',
        'missing:0',
        '',
      ]) {
        expect(
          () => store.accepted(wallet, 1, txid, inputs: {malformed}),
          throwsA(isA<BitcoinSpendGateUnavailable>()),
        );
        expect(store.tracked(wallet), isEmpty);
      }
    } finally {
      store.close();
    }
  });
}
