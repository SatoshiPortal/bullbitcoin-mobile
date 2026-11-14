import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/write.dart';
import 'package:transaction_sync/src/data/datasources/spend_gate_store_datasource.dart';
import 'package:transaction_sync/src/data/native_store_paths.dart';
import 'package:transaction_sync/src/data/datasources/revision_store_datasource.dart';
import 'package:transaction_sync/src/data/write/writer_lock.dart';

final class _Reserved implements ReservedAddressPort {
  @override
  Future<Result<bool, TransactionSyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}

final class _Catalog implements WalletCatalogPort {
  final List<PublicWalletDescriptor> wallets;
  _Catalog(this.wallets);
  @override
  Future<Result<PublicWalletDescriptor, TransactionSyncFailure>> find(
    WalletKey key,
  ) async => Ok(wallets.singleWhere((wallet) => wallet.key == key));
  @override
  Future<Result<List<PublicWalletDescriptor>, TransactionSyncFailure>>
  list() async => Ok(wallets);
}

void main() {
  late Directory dir;
  late ForegroundStores stores;
  late RevisionStoreDatasource revisions;
  late BitcoinSpendGate gate;
  late BitcoinWalletDescriptor wallet;
  late BitcoinWalletDescriptor other;
  const txid =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const replacement =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  BitcoinWalletDescriptor descriptor(String id) => BitcoinWalletDescriptor(
    key: WalletKey(id: id, network: BitcoinNetwork.testnet),
    scriptType: ScriptType.bip84,
    origin: 'public-fixture',
    externalDescriptor: 'wpkh(public/$id/0)',
    internalDescriptor: 'wpkh(public/$id/1)',
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('spend-gate-');
    wallet = descriptor('one');
    other = descriptor('two');
    stores = openForeground(
      documentsDirectory: dir.path,
      catalog: _Catalog([wallet, other]),
      reservedAddresses: _Reserved(),
    );
    revisions = RevisionStoreDatasource.openExisting(
      revisionStorePath(dir.path),
    );
    for (final descriptor in [wallet, other]) {
      revisions.begin(descriptor.key, WriteIntent.create);
      revisions.finish(descriptor.key, initializedDescriptor: descriptor);
    }
    gate = stores.spendGate;
  });
  tearDown(() async {
    revisions.close();
    await stores.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> accepted() async {
    final admission = await gate.acquire(wallet.key);
    expect(admission, isA<BitcoinSpendAdmission>());
    final lease = admission as BitcoinSpendAdmission;
    expect(lease.accepted(txid).durable, isTrue);
    lease.close();
  }

  test(
    'durable refusal survives restart and leaves another wallet available',
    () async {
      await accepted();
      expect(await gate.check(wallet.key), BitcoinSpendStatus.pending);
      expect(await gate.check(other.key), BitcoinSpendStatus.ready);
      final restarted = RevisionStoreDatasource.openExisting(
        revisionStorePath(dir.path),
      );
      try {
        final restored = BitcoinSpendGate(
          revisions: restarted,
          documentsDirectory: dir.path,
          catalog: _Catalog([wallet, other]),
        );
        expect(await restored.check(wallet.key), BitcoinSpendStatus.pending);
      } finally {
        restarted.close();
      }
    },
  );

  test(
    'observed predecessor admits RBF and revalidation cannot be cleared by revision recovery',
    () async {
      await accepted();
      expect(
        await gate.check(wallet.key, replacing: txid),
        BitcoinSpendStatus.replacementPending,
      );
      final store = SpendGateStoreDatasource.openExisting(
        spendGateStorePath(dir.path),
      );
      try {
        store.observed(wallet, 1, {txid});
        expect(await gate.check(wallet.key), BitcoinSpendStatus.ready);
        expect(
          await gate.check(wallet.key, replacing: txid),
          BitcoinSpendStatus.ready,
        );
        // The replacement is a new obligation, unobserved until a sync sees it.
        final admission = await gate.acquire(wallet.key);
        expect(
          (admission as BitcoinSpendAdmission).accepted(replacement).durable,
          isTrue,
        );
        admission.close();
        expect(await gate.check(wallet.key), BitcoinSpendStatus.pending);
        expect(
          await gate.check(wallet.key, replacing: replacement),
          BitcoinSpendStatus.replacementPending,
        );
        // The pass that sees the replacement settles the original it
        // conflicts with; both stay recorded.
        store.observed(wallet, 1, {replacement, txid});
        expect(store.tracked(wallet), [txid, replacement]);
        expect(
          await gate.check(wallet.key, replacing: replacement),
          BitcoinSpendStatus.ready,
        );
        // This marker precedes native persistence. Generic interrupted-write
        // reconciliation cannot erase it, even if native state was already saved.
        store.requireValidation(wallet.key);
        revisions.begin(wallet.key, WriteIntent.sync);
        revisions.finish(wallet.key);
        expect(await gate.check(wallet.key), BitcoinSpendStatus.pending);
        expect(
          await gate.check(wallet.key, replacing: replacement),
          BitcoinSpendStatus.replacementPending,
        );
        store.observed(wallet, 1, {});
        expect(await gate.check(wallet.key), BitcoinSpendStatus.pending);
      } finally {
        store.close();
      }
    },
  );

  test('a settled spend is retained and blocks again after a reset', () async {
    await accepted();
    final store = SpendGateStoreDatasource.openExisting(
      spendGateStorePath(dir.path),
    );
    try {
      final spent = {'${'b' * 64}:0', '${'b' * 64}:1'};
      store.observed(wallet, 1, {txid}, inputs: {txid: spent});
      expect(await gate.check(wallet.key), BitcoinSpendStatus.ready);
      // The next pass starts from nothing: absence is not evidence, and a
      // conflict that settled the spend must be proven again.
      store.requireValidation(wallet.key);
      store.observed(wallet, 1, {});
      expect(await gate.check(wallet.key), BitcoinSpendStatus.pending);
      expect(store.trackedInputs(wallet), {txid: spent});
    } finally {
      store.close();
    }
  });

  test('a stale create or delete leaves an observed spend ready', () async {
    await accepted();
    final store = SpendGateStoreDatasource.openExisting(
      spendGateStorePath(dir.path),
    );
    try {
      store.observed(wallet, 1, {txid});
    } finally {
      store.close();
    }
    expect(await gate.check(wallet.key), BitcoinSpendStatus.ready);
    for (final stale in [
      () => stores.writer.create(wallet.key, expectedGeneration: 0),
      () => stores.writer.delete(wallet.key, expectedGeneration: 0),
    ]) {
      expect(
        (await stale() as Err<WriterOutcome, TransactionSyncFailure>).failure,
        isA<TransactionSyncNotFoundFailure>(),
      );
      expect(await gate.check(wallet.key), BitcoinSpendStatus.ready);
    }
  });

  test('writer contention is busy, not an unobserved payment', () async {
    final held =
        WriterLock.acquire(dir.path, wallet.key)
            as Ok<WriterLock, TransactionSyncFailure>;
    try {
      expect(await gate.check(wallet.key), BitcoinSpendStatus.busy);
    } finally {
      held.value.release();
    }
    expect(await gate.check(wallet.key), BitcoinSpendStatus.ready);
  });

  test('revision quarantine marker keeps spend admission closed', () async {
    await accepted();
    final store = SpendGateStoreDatasource.openExisting(
      spendGateStorePath(dir.path),
    );
    store.observed(wallet, 1, {txid});
    store.close();
    final marker = File(recoveryMarkerPath(dir.path));
    marker.writeAsStringSync('pending', flush: true);
    expect(await gate.check(wallet.key), BitcoinSpendStatus.unavailable);
    // Even obligations whose native store could not be adopted are invalidated.
    stores.completeRecovery();
    expect(marker.existsSync(), isFalse);
    expect(await gate.check(wallet.key), BitcoinSpendStatus.pending);
  });

  test('generation reset never orphans an accepted obligation', () async {
    await accepted();
    final store = SpendGateStoreDatasource.openExisting(
      spendGateStorePath(dir.path),
    );
    try {
      store.observed(wallet, 99, {txid});
      expect(await gate.check(wallet.key), BitcoinSpendStatus.pending);
      store.observed(wallet, 1, {txid});
      expect(await gate.check(wallet.key), BitcoinSpendStatus.ready);
    } finally {
      store.close();
    }
  });

  test('failed recovery validation retains the global barrier', () async {
    await accepted();
    final marker = File(recoveryMarkerPath(dir.path));
    marker.writeAsStringSync('pending', flush: true);
    final db = sqlite3.open(spendGateStorePath(dir.path));
    try {
      db.execute(
        "CREATE TRIGGER fail_validation BEFORE UPDATE ON broadcasts BEGIN SELECT RAISE(FAIL, 'storage unavailable'); END",
      );
      expect(stores.completeRecovery, throwsA(isA<SqliteException>()));
      expect(marker.existsSync(), isTrue);
      expect(await gate.check(wallet.key), BitcoinSpendStatus.unavailable);
    } finally {
      db.dispose();
    }
  });

  test(
    'accepted storage failure stays accepted and blocks admission until recorded',
    () async {
      final db = sqlite3.open(spendGateStorePath(dir.path));
      db.execute(
        "CREATE TRIGGER fail_record BEFORE INSERT ON broadcasts BEGIN SELECT RAISE(FAIL, 'storage unavailable'); END",
      );
      final admission = await gate.acquire(wallet.key) as BitcoinSpendAdmission;
      final receipt = admission.accepted(txid);
      expect(receipt.txid, txid);
      expect(receipt.durable, isFalse);
      admission.close();
      expect(await gate.check(wallet.key), BitcoinSpendStatus.unavailable);
      db.execute('DROP TRIGGER fail_record');
      db.dispose();
      expect(await gate.check(wallet.key), BitcoinSpendStatus.pending);
    },
  );

  test('a lost gate is never recreated, even by the foreground', () async {
    final gateFile = File(spendGateStorePath(dir.path));
    gateFile.renameSync('${gateFile.path}.saved');
    // Metadata still opens for Liquid and reads; only the gate is refused.
    final reopened = openForeground(
      documentsDirectory: dir.path,
      catalog: _Catalog([wallet, other]),
      reservedAddresses: _Reserved(),
    );
    try {
      expect(
        () => SpendGateStoreDatasource.openExisting(gateFile.path),
        throwsA(isA<BitcoinSpendGateUnavailable>()),
      );
      expect(gateFile.existsSync(), isFalse);
      expect(
        await reopened.spendGate.check(wallet.key),
        BitcoinSpendStatus.unavailable,
      );
    } finally {
      await reopened.close();
    }
  });
}
