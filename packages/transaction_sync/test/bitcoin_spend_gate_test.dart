import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/write.dart';
import 'package:transaction_sync/src/write/bitcoin_spend_gate_store.dart';
import 'package:transaction_sync/src/write/revision_store.dart';

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

  test(
    'observed predecessor admits RBF and revalidation cannot be cleared by revision recovery',
    () async {
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
        // The pass that sees the replacement evicts and releases the original.
        store.observed(wallet, 1, {replacement}, released: {txid});
        expect(store.tracked(wallet), [replacement]);
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

  test('proof that a spend cannot confirm releases it for good', () async {
    await accepted();
    final store = BitcoinSpendGateStore(revisions.spendGatePath);
    try {
      store.observed(
        wallet,
        1,
        {txid},
        inputs: {
          txid: {'${'b' * 64}:0', '${'b' * 64}:1'},
        },
      );
      expect(store.trackedInputs(wallet), {
        txid: {'${'b' * 64}:0', '${'b' * 64}:1'},
      });
      // Revalidation alone releases nothing: absence is not evidence.
      store.requireValidation(wallet.key);
      store.observed(wallet, 1, {});
      expect(await gate.check(wallet.key), BitcoinSpendStatus.pending);
      store.observed(wallet, 1, {}, released: {txid});
      expect(store.tracked(wallet), isEmpty);
      expect(await gate.check(wallet.key), BitcoinSpendStatus.ready);
    } finally {
      store.close();
    }
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
      db.dispose();
    }
  });

  test(
    'accepted storage failure stays accepted and blocks admission until recorded',
    () async {
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
      db.dispose();
      expect(await gate.check(wallet.key), BitcoinSpendStatus.pending);
    },
  );

  test('headless opening does not provision missing gate schema', () async {
    final emptyPath = '${dir.path}/headless.sqlite';
    expect(
      () => RevisionStore(emptyPath, existingOnly: true),
      throwsA(isA<BitcoinSpendGateUnavailable>()),
    );
    expect(File(emptyPath).existsSync(), isFalse);
    final gateFile = File(revisions.spendGatePath);
    gateFile.renameSync('${gateFile.path}.saved');
    expect(
      () => RevisionStore(writerMetadataPath(dir.path), existingOnly: true),
      throwsA(isA<BitcoinSpendGateUnavailable>()),
    );
    expect(
      () => RevisionStore(writerMetadataPath(dir.path)),
      throwsA(isA<BitcoinSpendGateUnavailable>()),
    );
    expect(gateFile.existsSync(), isFalse);
  });
}
