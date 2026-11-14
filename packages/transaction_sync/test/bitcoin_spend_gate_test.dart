import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/write.dart';
import 'package:transaction_sync/src/write/bitcoin_spend_gate_store.dart';
import 'package:transaction_sync/src/write/revision_store.dart';
import 'package:transaction_sync/src/write/writer_lock.dart';

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
  late RevisionStore revisions;
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
    revisions = RevisionStore(writerMetadataPath(dir.path));
    revisions.openSpendGate().close();
    wallet = descriptor('one');
    other = descriptor('two');
    for (final descriptor in [wallet, other]) {
      revisions.begin(descriptor.key, WriteIntent.create);
      revisions.finish(descriptor.key, initializedDescriptor: descriptor);
    }
    gate = BitcoinSpendGate(
      revisions: revisions,
      lockDirectory: writerLockDirectory(dir.path),
      catalog: _Catalog([wallet, other]),
    );
  });
  tearDown(() async {
    await revisions.close();
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
      final restarted = RevisionStore(
        writerMetadataPath(dir.path),
        existingOnly: true,
      );
      try {
        final restored = BitcoinSpendGate(
          revisions: restarted,
          lockDirectory: writerLockDirectory(dir.path),
          catalog: _Catalog([wallet, other]),
        );
        expect(await restored.check(wallet.key), BitcoinSpendStatus.pending);
      } finally {
        await restarted.close();
      }
    },
  );

  test('observed predecessor admits RBF and revalidation cannot be cleared by revision recovery', () async {
    await accepted();
    expect(
      await gate.check(wallet.key, replacing: txid),
      BitcoinSpendStatus.replacementPending,
    );
    final store = BitcoinSpendGateStore(revisions.spendGatePath);
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
  });

  test('a settled spend is retained and blocks again after a reset', () async {
    await accepted();
    final store = BitcoinSpendGateStore(revisions.spendGatePath);
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

  test('writer contention is busy, not an unobserved payment', () async {
    final held = WriterLock.acquire(
      writerLockDirectory(dir.path),
      wallet.key,
    ) as Ok<WriterLock, TransactionSyncFailure>;
    try {
      expect(await gate.check(wallet.key), BitcoinSpendStatus.busy);
    } finally {
      held.value.release();
    }
    expect(await gate.check(wallet.key), BitcoinSpendStatus.ready);
  });

  test('revision quarantine marker keeps spend admission closed', () async {
    await accepted();
    final store = BitcoinSpendGateStore(revisions.spendGatePath);
    store.observed(wallet, 1, {txid});
    store.close();
    final marker = File('${writerMetadataPath(dir.path)}.recovery');
    marker.writeAsStringSync('pending', flush: true);
    expect(await gate.check(wallet.key), BitcoinSpendStatus.unavailable);
    // Even obligations whose native store could not be adopted are invalidated.
    revisions.completeRecovery();
    expect(marker.existsSync(), isFalse);
    expect(await gate.check(wallet.key), BitcoinSpendStatus.pending);
  });

  test('generation reset never orphans an accepted obligation', () async {
    await accepted();
    final store = BitcoinSpendGateStore(revisions.spendGatePath);
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
    final marker = File('${writerMetadataPath(dir.path)}.recovery');
    marker.writeAsStringSync('pending', flush: true);
    final db = sqlite3.open(revisions.spendGatePath);
    try {
      db.execute(
        "CREATE TRIGGER fail_validation BEFORE UPDATE ON broadcasts BEGIN SELECT RAISE(FAIL, 'storage unavailable'); END",
      );
      expect(revisions.completeRecovery, throwsA(isA<SqliteException>()));
      expect(marker.existsSync(), isTrue);
      expect(await gate.check(wallet.key), BitcoinSpendStatus.unavailable);
    } finally {
      db.close();
    }
  });

  test('accepted storage failure stays accepted and blocks admission until recorded', () async {
    final db = sqlite3.open(revisions.spendGatePath);
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
    db.close();
    expect(await gate.check(wallet.key), BitcoinSpendStatus.pending);
  });

  test('headless opening does not provision missing gate schema', () async {
    final emptyPath = '${dir.path}/headless.sqlite';
    expect(
      () => RevisionStore(emptyPath, existingOnly: true),
      throwsA(isA<BitcoinSpendGateUnavailable>()),
    );
    expect(File(emptyPath).existsSync(), isFalse);
    final gateFile = File(revisions.spendGatePath);
    gateFile.renameSync('${gateFile.path}.saved');
    // Metadata still opens for Liquid and reads; only the gate is refused,
    // and a provisioned gate that went missing is never silently recreated.
    for (final existingOnly in [true, false]) {
      final reopened = RevisionStore(
        writerMetadataPath(dir.path),
        existingOnly: existingOnly,
      );
      expect(
        reopened.openSpendGate,
        throwsA(isA<BitcoinSpendGateUnavailable>()),
      );
      await reopened.close();
    }
    expect(gateFile.existsSync(), isFalse);
    expect(await gate.check(wallet.key), BitcoinSpendStatus.unavailable);
  });
}
