import 'dart:io';

import 'package:primitives/primitives.dart';
import '../../domain/bitcoin_spend.dart';
import '../../domain/sync_failure.dart';
import '../../domain/public_wallet_descriptor.dart';
import '../../domain/ports/wallet_catalog_port.dart';
import '../../domain/wallet_key.dart';
import '../../domain/wallet_revision.dart';
import '../datasources/spend_gate_store_datasource.dart';
import '../native_store_paths.dart';
import '../datasources/revision_store_datasource.dart';
import 'writer_lock.dart';
import '../lease_diagnostics.dart';

/// Foreground spend admission shares the single writer's cross-isolate lease.
/// Only durable receipts survive restart; a post-accept storage failure blocks
/// this process and is retried on the next admission, never reported as rejection.
final class BitcoinSpendGate {
  final RevisionStoreDatasource revisions;
  final String documentsDirectory;
  final WalletCatalogPort catalog;

  /// The freeze import must be witnessed before any spend: until then a
  /// frozen coin is not known to be frozen.
  final Future<Result<void, SyncFailure>> Function() freezesReady;
  static final _pending =
      <(String, WalletKey), (PublicWalletDescriptor, int, String)>{};

  const BitcoinSpendGate({
    required this.revisions,
    required this.documentsDirectory,
    required this.catalog,
    required this.freezesReady,
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
    // A hand-off records a spend already made elsewhere; it protects, so it
    // does not wait for the freezes.
    if (!handoff && await freezesReady() is Err) {
      return const BitcoinSpendRefused(BitcoinSpendStatus.unavailable);
    }
    final acquired = await WriterLock.acquireWriter(
      documentsDirectory,
      key,
      diagnostics: LeaseDiagnostics(
        role: LeaseRole.writer,
        intent: LeaseIntent.sync,
      ),
    );
    if (acquired case Err(:final failure)) {
      // Contention says nothing about the wallet's payments.
      return BitcoinSpendRefused(
        failure is SyncBusyFailure
            ? BitcoinSpendStatus.busy
            : BitcoinSpendStatus.unavailable,
      );
    }
    final lock = (acquired as Ok<WriterLock, SyncFailure>).value;
    SpendGateStoreDatasource? store;
    try {
      // Quarantined metadata: no spend until every wallet has been adopted.
      if (File(recoveryMarkerPath(documentsDirectory)).existsSync()) {
        throw const BitcoinSpendGateUnavailable();
      }
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
          (found as Ok<PublicWalletDescriptor, SyncFailure>).value;
      final path = spendGateStorePath(documentsDirectory);
      store = SpendGateStoreDatasource.openExisting(path);
      final pendingKey = (path, key);
      final pending = _pending[pendingKey];
      if (pending != null) {
        store.accepted(pending.$1, pending.$2, pending.$3);
        _pending.remove(pendingKey);
      }
      final tracked = store.tracked(descriptor);
      if (store.generationMismatch(key, record.state.stamp.generation)) {
        store.requireValidation(key);
      }
      // An observed tracked spend may be replaced. Broadcasting the
      // replacement records it as a new obligation; a pass that sees the
      // replacement settles the original by conflict, never by eviction.
      final status =
          replacing != null &&
              tracked.contains(replacing) &&
              !store.isObserved(key, replacing)
          ? BitcoinSpendStatus.replacementPending
          : store.blocked(descriptor)
          ? BitcoinSpendStatus.pending
          : null;
      if (!handoff && status != null) {
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
  final SpendGateStoreDatasource _store;
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
