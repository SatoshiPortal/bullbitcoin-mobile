import 'package:primitives/primitives.dart';
import '../../transaction_sync.dart';
import 'bitcoin_spend_gate_store.dart';
import 'revision_store.dart';
import 'writer_lock.dart';
import 'lease_diagnostics.dart';

/// No timeout, absence or recovery operation grants spend permission.
enum BitcoinSpendStatus { ready, pending, unavailable, replacementUnsupported }

final class BitcoinBroadcastReceipt {
  final String txid;
  final bool durable;
  const BitcoinBroadcastReceipt(this.txid, {required this.durable});
}

/// Foreground spend admission shares the single writer's cross-isolate lease.
/// Only durable receipts survive restart; a post-accept storage failure blocks
/// this process and is retried on the next admission, never reported as rejection.
final class BitcoinSpendGate {
  final RevisionStore revisions;
  final String lockDirectory;
  final WalletCatalogPort catalog;
  static final _pending =
      <(String, WalletKey), (PublicWalletDescriptor, int, String)>{};

  const BitcoinSpendGate({
    required this.revisions,
    required this.lockDirectory,
    required this.catalog,
  });

  Future<BitcoinSpendStatus> check(WalletKey key, {String? replacing}) async {
    final admission = await acquire(key, replacing: replacing);
    if (admission case BitcoinSpendAdmission()) {
      admission.close();
      return BitcoinSpendStatus.ready;
    }
    return (admission as BitcoinSpendRefused).status;
  }

  Future<BitcoinSpendAdmissionResult> acquire(
    WalletKey key, {
    String? replacing,
    bool handoff = false,
  }) async {
    if (key.network is! BitcoinNetwork) {
      return const BitcoinSpendRefused(BitcoinSpendStatus.unavailable);
    }
    final acquired = await WriterLock.acquireWriter(
      lockDirectory,
      key,
      diagnostics: LeaseDiagnostics(
        role: LeaseRole.writer,
        intent: LeaseIntent.sync,
      ),
    );
    if (acquired case Err()) {
      return const BitcoinSpendRefused(BitcoinSpendStatus.unavailable);
    }
    final lock = (acquired as Ok<WriterLock, TransactionSyncFailure>).value;
    BitcoinSpendGateStore? store;
    try {
      if (revisions.recoveryPending) throw const BitcoinSpendGateUnavailable();
      final record = revisions.record(key);
      if (record == null ||
          record.intent != null ||
          record.needsSync ||
          record.state.syncFailed ||
          record.state.lifecycle != WalletLifecycle.active ||
          record.state.initializedSchema != writerSchemaVersion) {
        throw const BitcoinSpendGateUnavailable();
      }
      final found = await catalog.find(key);
      if (found case Err()) throw const BitcoinSpendGateUnavailable();
      final descriptor =
          (found as Ok<PublicWalletDescriptor, TransactionSyncFailure>).value;
      store = BitcoinSpendGateStore(revisions.spendGatePath);
      final pendingKey = (revisions.spendGatePath, key);
      final pending = _pending[pendingKey];
      if (pending != null) {
        store.accepted(pending.$1, pending.$2, pending.$3);
        _pending.remove(pendingKey);
      }
      final tracked = store.tracked(descriptor);
      if (store.generationMismatch(key, record.state.stamp.generation)) {
        store.requireValidation(key);
      }
      if (!handoff &&
          (store.blocked(descriptor) ||
              (replacing != null && tracked.contains(replacing)))) {
        final status = replacing != null && tracked.contains(replacing)
            ? BitcoinSpendStatus.replacementUnsupported
            : BitcoinSpendStatus.pending;
        store.close();
        lock.release();
        return BitcoinSpendRefused(status);
      }
      return BitcoinSpendAdmission._(
        lock,
        store,
        descriptor,
        record.state.stamp,
        pendingKey,
      );
    } on Exception {
      store?.close();
      lock.release();
      return const BitcoinSpendRefused(BitcoinSpendStatus.unavailable);
    } catch (_) {
      store?.close();
      lock.release();
      rethrow;
    }
  }
}

sealed class BitcoinSpendAdmissionResult {
  const BitcoinSpendAdmissionResult();
}

final class BitcoinSpendRefused extends BitcoinSpendAdmissionResult {
  final BitcoinSpendStatus status;
  const BitcoinSpendRefused(this.status);
}

final class BitcoinSpendAdmission extends BitcoinSpendAdmissionResult {
  final WriterLock _lock;
  final BitcoinSpendGateStore _store;
  final PublicWalletDescriptor _descriptor;
  final WalletRevision revision;
  final (String, WalletKey) _pendingKey;
  bool _closed = false;

  BitcoinSpendAdmission._(
    this._lock,
    this._store,
    this._descriptor,
    this.revision,
    this._pendingKey,
  );

  BitcoinBroadcastReceipt accepted(String txid) {
    if (_closed) throw StateError('Spend admission closed');
    BitcoinSpendGate._pending[_pendingKey] = (
      _descriptor,
      revision.generation,
      txid,
    );
    try {
      _store.accepted(_descriptor, revision.generation, txid);
      BitcoinSpendGate._pending.remove(_pendingKey);
      return BitcoinBroadcastReceipt(txid, durable: true);
    } on Exception {
      return BitcoinBroadcastReceipt(txid, durable: false);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    try {
      _store.close();
    } finally {
      _lock.release();
    }
  }
}
