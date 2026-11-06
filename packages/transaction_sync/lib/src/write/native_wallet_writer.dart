import 'dart:math' as math;

import 'package:bull_logger/bull_logger.dart';

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../transaction_sync.dart';
import 'native_write_session.dart';
import 'revision_store.dart';
import 'writer_lock.dart';
import 'writer_sync_operation.dart';

/// Invoke inside the isolate doing native IO. The caller owns the shared
/// RevisionStore and subscribes before reading. No method times out native work.
final class NativeWalletWriter implements LiquidReadAdmission {
  final String lockDirectory;
  final RevisionStore revisions;
  final WalletCatalogPort _catalog;
  final ReservedAddressPort _reserved;
  final NativeWriteSessions _sessions;
  final Map<WalletKey, Type> _failures = {};

  NativeWalletWriter({
    required this.lockDirectory,
    required this.revisions,
    required String documentsDirectory,
    required this._catalog,
    required ReservedAddressPort reservedAddresses,
  }) : _reserved = reservedAddresses,
       _sessions = SdkWriteSessions(documentsDirectory);

  @visibleForTesting
  NativeWalletWriter.withSessions({
    required this.lockDirectory,
    required this.revisions,
    required this._catalog,
    required ReservedAddressPort reservedAddresses,
    required this._sessions,
  }) : _reserved = reservedAddresses;

  @useResult
  Future<Result<WriterOutcome, TransactionSyncFailure>> create(
    WalletKey key, {
    required int expectedGeneration,
  }) => _run(key, expectedGeneration, WriteIntent.create, () async {
    final old = revisions.record(key);
    _expectGeneration(old, expectedGeneration);
    final descriptor = await _descriptor(key);
    if (old != null && old.state.lifecycle == WalletLifecycle.active) {
      revisions.begin(key, WriteIntent.load);
      final session = await _sessions.open(descriptor, create: false);
      session.close();
      return WriterCommitted(revisions.finish(key));
    }
    revisions.begin(key, WriteIntent.create);
    final session = await _sessions.open(descriptor, create: true);
    session.close();
    return WriterCommitted(revisions.finish(key));
  });

  @useResult
  Future<Result<ReceiveAddressIssued, TransactionSyncFailure>> receive(
    WalletKey key, {
    required int expectedGeneration,
  }) => _run(key, expectedGeneration, WriteIntent.receive, () async {
    final record = _active(key, expectedGeneration);
    if (record.needsSync) {
      throw const _WriterFailure(TransactionSyncNeedsRepairFailure());
    }
    final descriptor = await _descriptor(key);
    revisions.begin(key, WriteIntent.receive);
    final session = await _sessions.open(descriptor, create: false);
    try {
      var index = math.max(
        record.issued ?? 0,
        await session.firstUnusedIndex(),
      );
      while (index < 0x80000000) {
        final address = await session.address(index);
        final reserved = _value(await _reserved.isReserved(key, address));
        if (!reserved && !await session.isUsed(index, address)) {
          // Reserve before native mutation. Reconciliation completes this
          // candidate; the next call checks reservations and usage again.
          revisions.reserveReceive(key, index);
          await session.revealAndPersist(index);
          final revision = revisions.finish(key, issued: index);
          return ReceiveAddressIssued(revision, address: address, index: index);
        }
        index++;
      }
      throw const _WriterFailure(TransactionSyncStorageFailure());
    } finally {
      session.close();
    }
  });

  @useResult
  Future<Result<WriterOutcome, TransactionSyncFailure>> delete(
    WalletKey key, {
    required int expectedGeneration,
  }) => _run(key, expectedGeneration, WriteIntent.delete, () async {
    final record = revisions.record(key);
    _expectGeneration(record, expectedGeneration);
    if (record == null) {
      throw const _WriterFailure(TransactionSyncNotFoundFailure());
    }
    if (record.state.lifecycle == WalletLifecycle.deleted) {
      return WriterUnchanged(record.state.stamp);
    }
    revisions.begin(key, WriteIntent.delete);
    await _sessions.delete(key);
    return WriterCommitted(revisions.finish(key));
  }, deleting: true);

  /// Repair is explicit and only erases a store after the precise LWK conflict.
  /// It keeps issued metadata and requires a successful sync before receive.
  @useResult
  Future<Result<WriterOutcome, TransactionSyncFailure>> repair(
    WalletKey key, {
    required int expectedGeneration,
  }) => _run(key, expectedGeneration, WriteIntent.repair, () async {
    final record = _active(key, expectedGeneration);
    if (key.network is! LiquidNetwork) {
      throw const _WriterFailure(TransactionSyncUnsupportedNetworkFailure());
    }
    final descriptor = await _descriptor(key);
    revisions.begin(key, WriteIntent.load);
    try {
      final session = await _sessions.open(descriptor, create: false);
      session.close();
      return WriterCommitted(revisions.finish(key));
    } on Object catch (error) {
      if (!isLiquidStatusConflict(error)) rethrow;
    }
    revisions.requireRepair(key);
    await _rebuild(descriptor, record.issued);
    return WriterCommitted(revisions.finish(key, needsSync: true));
  }, allowRepairIntent: true);

  @useResult
  Future<Result<WriterOutcome, TransactionSyncFailure>> sync(
    WalletKey key, {
    required int expectedGeneration,
    required WriterSyncOperation operation,
  }) => _run(key, expectedGeneration, WriteIntent.sync, () async {
    final record = _active(key, expectedGeneration);
    final descriptor = await _descriptor(key);
    revisions.begin(key, WriteIntent.sync);
    late Result<void, TransactionSyncFailure> result;
    try {
      result = await operation.execute(
        descriptor,
        issuedReceiveIndex: record.issued,
      );
    } on Object catch (error) {
      if (isLiquidStatusConflict(error)) revisions.requireRepair(key);
      rethrow;
    }
    if (result case Err(failure: TransactionSyncNeedsRepairFailure())) {
      revisions.requireRepair(key);
    }
    _value(result);
    return WriterCommitted(revisions.finish(key, needsSync: false));
  });

  @override
  @useResult
  Future<Result<LiquidReadLease, TransactionSyncFailure>> acquire(
    WalletKey key,
  ) async {
    if (key.network.env != NetworkEnv.mainnet &&
        key.network.env != NetworkEnv.testnet) {
      return const Err(TransactionSyncUnsupportedNetworkFailure());
    }
    final acquisition = WriterLock.acquire(lockDirectory, key);
    if (acquisition case Err(:final failure)) {
      _reportFailure(key, failure);
      return Err(failure);
    }
    final lock = (acquisition as Ok<WriterLock, TransactionSyncFailure>).value;
    try {
      final record = revisions.record(key);
      if (record == null || record.state.lifecycle == WalletLifecycle.deleted) {
        throw const _WriterFailure(TransactionSyncNotFoundFailure());
      }
      if (record.state.lifecycle != WalletLifecycle.active ||
          record.state.initializedSchema != writerSchemaVersion) {
        throw const _WriterFailure(TransactionSyncBusyFailure());
      }
      if (record.needsSync) {
        throw const _WriterFailure(TransactionSyncNeedsRepairFailure());
      }
      return Ok(_ReadLease(lock, record.state.stamp));
    } on Object catch (error) {
      lock.release();
      final failure = _map(error);
      _reportFailure(key, failure);
      return Err(failure);
    }
  }

  Future<Result<T, TransactionSyncFailure>> _run<T>(
    WalletKey key,
    int expectedGeneration,
    WriteIntent intent,
    Future<T> Function() operation, {
    bool allowRepairIntent = false,
    bool deleting = false,
  }) async {
    if (key.network.env != NetworkEnv.mainnet &&
        key.network.env != NetworkEnv.testnet) {
      return const Err(TransactionSyncUnsupportedNetworkFailure());
    }
    final acquisition = WriterLock.acquire(lockDirectory, key);
    if (acquisition case Err(:final failure)) {
      _reportFailure(key, failure);
      return Err(failure);
    }
    final lock = (acquisition as Ok<WriterLock, TransactionSyncFailure>).value;
    final watch = Stopwatch()..start();
    log.fine(
      'Wallet writer lock acquired intent=${intent.name} network=${key.network} generation=$expectedGeneration',
    );
    try {
      _expectGeneration(revisions.record(key), expectedGeneration);
      // Delete must remain possible for damaged stores: it supersedes an
      // unfinished write, but completes an existing tombstone without another
      // generation increment.
      if (!deleting || revisions.record(key)?.intent == WriteIntent.delete) {
        await _reconcile(key, allowRepairIntent: allowRepairIntent);
      }
      final value = await operation();
      final stamp = revisions.record(key)?.state.stamp;
      _failures.remove(key);
      log.fine(
        'Wallet writer operation committed intent=${intent.name} network=${key.network} generation=${stamp?.generation} revision=${stamp?.revision} duration_ms=${watch.elapsedMilliseconds}',
      );
      return Ok(value);
    } on Object catch (error) {
      final failure = _map(error);
      _reportFailure(key, failure);
      return Err(failure);
    } finally {
      lock.release();
    }
  }

  Future<void> _reconcile(
    WalletKey key, {
    bool allowRepairIntent = false,
  }) async {
    final record = revisions.record(key);
    if (record == null || record.intent == null) return;
    log.warning(
      'Wallet writer reconciling interrupted intent=${record.intent?.name} network=${key.network} generation=${record.state.stamp.generation} revision=${record.state.stamp.revision}',
    );
    if (record.intent == WriteIntent.delete) {
      await _sessions.delete(key);
      revisions.finish(key);
      return;
    }
    final descriptor = await _descriptor(key);
    if (record.intent == WriteIntent.repair) {
      if (!allowRepairIntent) {
        throw const _WriterFailure(TransactionSyncNeedsRepairFailure());
      }
      await _rebuild(descriptor, record.issued);
      revisions.finish(key, needsSync: true);
      return;
    }
    late NativeWriteSession session;
    try {
      session = await _sessions.open(
        descriptor,
        create: record.intent == WriteIntent.create,
      );
    } on Object catch (error) {
      if (!allowRepairIntent || !isLiquidStatusConflict(error)) rethrow;
      revisions.requireRepair(key);
      await _rebuild(descriptor, record.issued);
      revisions.finish(key, needsSync: true);
      return;
    }
    try {
      final candidate = record.candidate;
      if (record.intent == WriteIntent.receive && candidate != null) {
        await session.revealAndPersist(candidate);
      }
      // Unknown sync completion still invalidates snapshots. It does not
      // unblock post-repair receive or produce any payment-seen receipt.
      revisions.finish(key, issued: candidate ?? record.issued);
    } finally {
      session.close();
    }
  }

  Future<void> _rebuild(PublicWalletDescriptor descriptor, int? issued) async {
    log.warning(
      'Wallet writer repair executed network=${descriptor.key.network}',
    );
    await _sessions.delete(descriptor.key);
    final session = await _sessions.open(descriptor, create: true);
    try {
      if (issued != null) await session.revealAndPersist(issued);
    } finally {
      session.close();
    }
  }

  Future<PublicWalletDescriptor> _descriptor(WalletKey key) async {
    final descriptor = _value(await _catalog.find(key));
    if (descriptor.key != key) {
      throw const _WriterFailure(TransactionSyncInvalidCatalogFailure());
    }
    return descriptor;
  }

  RevisionRecord _active(WalletKey key, int generation) {
    final record = revisions.record(key);
    _expectGeneration(record, generation);
    if (record == null || record.state.lifecycle != WalletLifecycle.active) {
      throw const _WriterFailure(TransactionSyncNotFoundFailure());
    }
    return record;
  }

  void _expectGeneration(RevisionRecord? record, int generation) {
    if ((record?.state.stamp.generation ?? 0) != generation) {
      throw const _WriterFailure(TransactionSyncNotFoundFailure());
    }
  }

  void _reportFailure(WalletKey key, TransactionSyncFailure failure) {
    if (_failures[key] == failure.runtimeType) return;
    _failures[key] = failure.runtimeType;
    if (failure is TransactionSyncStorageFailure) {
      log.severe(
        message: 'Wallet writer unexpected storage failure',
        error: failure.runtimeType.toString(),
        trace: StackTrace.empty,
      );
    } else {
      log.warning(
        'Wallet writer operation unavailable network=${key.network} category=${failure.runtimeType}',
      );
    }
  }

  static T _value<T>(Result<T, TransactionSyncFailure> result) =>
      switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw _WriterFailure(failure),
      };

  static TransactionSyncFailure _map(Object error) {
    if (error is Error) throw error;
    if (error is _WriterFailure) return error.failure;
    if (error is NativeStoreMissing) {
      return const TransactionSyncNotFoundFailure();
    }
    if (error is NativeNetworkUnsupported) {
      return const TransactionSyncUnsupportedNetworkFailure();
    }
    if (error is SqliteException && error.resultCode == 5) {
      return const TransactionSyncBusyFailure();
    }
    if (isLiquidStatusConflict(error)) {
      return const TransactionSyncNeedsRepairFailure();
    }
    return const TransactionSyncStorageFailure();
  }
}

final class _WriterFailure implements Exception {
  final TransactionSyncFailure failure;
  const _WriterFailure(this.failure);
}

final class _ReadLease implements LiquidReadLease {
  final WriterLock _lock;
  @override
  final WalletRevision revision;
  _ReadLease(this._lock, this.revision);
  @override
  Future<void> release() async => _lock.release();
}
