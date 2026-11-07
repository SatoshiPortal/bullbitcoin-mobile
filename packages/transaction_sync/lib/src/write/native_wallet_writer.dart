import 'dart:math' as math;

import 'writer_diagnostics.dart';
import 'store_identity.dart';

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
  final WriterDiagnosticSink _diagnostics;
  final bool reportFailures;

  NativeWalletWriter({
    required this.lockDirectory,
    required this.revisions,
    required String documentsDirectory,
    required this._catalog,
    required ReservedAddressPort reservedAddresses,
    this._diagnostics = persistWriterDiagnostic,
    this.reportFailures = true,
  }) : _reserved = reservedAddresses,
       _sessions = SdkWriteSessions(documentsDirectory);

  @visibleForTesting
  NativeWalletWriter.withSessions({
    required this.lockDirectory,
    required this.revisions,
    required this._catalog,
    required ReservedAddressPort reservedAddresses,
    required this._sessions,
    this.reportFailures = true,
  }) : _reserved = reservedAddresses,
       _diagnostics = persistWriterDiagnostic;

  /// Re-import reserves the next generation before publishing a new catalog
  /// row, so startup cannot mistake it for the row of an interrupted deletion.
  @useResult
  Future<Result<WriterOutcome, TransactionSyncFailure>> prepareReimport(
    WalletKey key, {
    required int expectedGeneration,
  }) => _run(key, expectedGeneration, WriteIntent.create, () async {
    final old = revisions.record(key);
    _expectGeneration(old, expectedGeneration);
    if (old == null || old.state.lifecycle != WalletLifecycle.deleted) {
      throw const _WriterFailure(TransactionSyncBusyFailure());
    }
    switch (await _catalog.find(key)) {
      case Err(failure: TransactionSyncNotFoundFailure()):
        break;
      case Err(:final failure):
        throw _WriterFailure(failure);
      case Ok():
        throw const _WriterFailure(TransactionSyncBusyFailure());
    }
    revisions.begin(key, WriteIntent.create);
    final prepared = revisions.record(key);
    if (prepared == null) throw StateError('Missing prepared generation');
    return WriterUnchanged(prepared.state.stamp);
  }, preparing: true);

  @useResult
  Future<Result<WriterOutcome, TransactionSyncFailure>> create(
    WalletKey key, {
    required int expectedGeneration,
    bool existingOnly = false,
  }) => _run(key, expectedGeneration, WriteIntent.create, () async {
    final old = revisions.record(key);
    _expectGeneration(old, expectedGeneration);
    final descriptor = await _descriptor(key);
    if (existingOnly ||
        (old != null && old.state.lifecycle == WalletLifecycle.active)) {
      revisions.begin(key, WriteIntent.load);
      late NativeWriteSession session;
      var rebuilt = false;
      try {
        session = await _sessions.open(descriptor, create: false);
      } on NativeStoreMissing {
        if (old == null || old.state.initializedSchema == 0) {
          revisions.cancelUnchanged(key, old);
          rethrow;
        }
        _diagnostics(
          WriterLogLevel.warning,
          'Wallet writer rebuilding missing store network=${key.network}',
        );
        revisions.requireRebuild(key);
        session = await _sessions.open(descriptor, create: true);
        rebuilt = true;
      }
      try {
        if (old?.issued case final issued? when rebuilt) {
          await session.revealAndPersist(issued);
        }
        final issued = _highestIndex(
          old?.issued,
          await session.lastIssuedIndex(),
        );
        if (!rebuilt &&
            old != null &&
            old.state.lifecycle == WalletLifecycle.active &&
            old.state.initializedSchema == writerSchemaVersion &&
            old.descriptorHash == descriptorDigest(descriptor) &&
            old.liquidCachePath == session.liquidCachePath &&
            old.issued == issued) {
          revisions.cancelUnchanged(key, old);
          return WriterUnchanged(old.state.stamp);
        }
        return WriterCommitted(
          revisions.finish(
            key,
            needsSync: rebuilt ? true : null,
            issued: issued,
            initializedDescriptor: descriptor,
            liquidCachePath: session.liquidCachePath,
          ),
        );
      } finally {
        session.close();
      }
    }
    revisions.begin(key, WriteIntent.create);
    final session = await _sessions.open(descriptor, create: true);
    try {
      return WriterCommitted(
        revisions.finish(
          key,
          issued: _highestIndex(old?.issued, await session.lastIssuedIndex()),
          initializedDescriptor: descriptor,
          liquidCachePath: session.liquidCachePath,
        ),
      );
    } finally {
      session.close();
    }
  });

  @useResult
  Future<Result<ReceiveAddressIssued, TransactionSyncFailure>> receive(
    WalletKey key, {
    required int expectedGeneration,
    bool advance = false,
  }) => _run(key, expectedGeneration, WriteIntent.receive, () async {
    final record = _active(key, expectedGeneration);
    if (record.needsSync) {
      throw const _WriterFailure(TransactionSyncNeedsRepairFailure());
    }
    final descriptor = await _descriptor(key);
    revisions.begin(key, WriteIntent.receive);
    final session = await _sessions.open(descriptor, create: false);
    try {
      final nativeIssued = await session.lastIssuedIndex();
      final highWater = math.max(record.issued ?? -1, nativeIssued ?? -1);
      var index = math.max(
        advance ? highWater + 1 : highWater,
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
    if (record != null && record.state.lifecycle == WalletLifecycle.deleted) {
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
      try {
        return WriterCommitted(
          revisions.finish(
            key,
            initializedDescriptor: descriptor,
            liquidCachePath: session.liquidCachePath,
          ),
        );
      } finally {
        session.close();
      }
    } on Object catch (error) {
      if (!isLiquidStatusConflict(error)) rethrow;
    }
    revisions.requireRepair(key);
    final cachePath = await _rebuild(descriptor, record.issued);
    return WriterCommitted(
      revisions.finish(
        key,
        needsSync: true,
        initializedDescriptor: descriptor,
        liquidCachePath: cachePath,
      ),
    );
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
    } else if (result is Err) {
      if (operation case WriterSyncMutation(mayHaveMutated: false)) {
        revisions.cancelUnchanged(key, record);
      } else {
        // Native work completed with an uncertain mutation: invalidate readers,
        // but never claim a successful sync or clear a prior repair barrier.
        final stamp = revisions.finish(key, syncFailed: true);
        _diagnostics(
          WriterLogLevel.fine,
          'Writer revision invalidated generation=${stamp.generation} revision=${stamp.revision} reason=${(result as Err<void, TransactionSyncFailure>).failure.logCode}',
        );
      }
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
      final failure = _map(key, error);
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
    bool preparing = false,
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
    _diagnostics(
      WriterLogLevel.fine,
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
      _diagnostics(
        WriterLogLevel.fine,
        'Wallet writer finished intent=${intent.name} outcome=${preparing
            ? 'prepared'
            : value is WriterUnchanged
            ? 'unchanged'
            : 'committed'} network=${key.network} generation=${stamp?.generation} revision=${stamp?.revision} duration_ms=${watch.elapsedMilliseconds}',
      );
      return Ok(value);
    } on Object catch (error) {
      final failure = _map(key, error);
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
    _diagnostics(
      WriterLogLevel.warning,
      'Wallet writer reconciling interrupted intent=${record.intent?.name} network=${key.network} generation=${record.state.stamp.generation} revision=${record.state.stamp.revision}',
    );
    if (record.intent == WriteIntent.delete) {
      await _sessions.delete(key);
      revisions.finish(key);
      return;
    }
    final descriptor = await _descriptor(key);
    if (record.intent == WriteIntent.rebuild) {
      await _resumeRebuild(descriptor, record.issued);
      return;
    }
    if (record.intent == WriteIntent.repair) {
      if (!allowRepairIntent) {
        throw const _WriterFailure(TransactionSyncNeedsRepairFailure());
      }
      final cachePath = await _rebuild(descriptor, record.issued);
      revisions.finish(
        key,
        needsSync: true,
        initializedDescriptor: descriptor,
        liquidCachePath: cachePath,
      );
      return;
    }
    late NativeWriteSession session;
    try {
      session = await _sessions.open(
        descriptor,
        create: record.intent == WriteIntent.create,
      );
    } on NativeStoreMissing {
      if (record.state.initializedSchema == 0 &&
          record.intent == WriteIntent.load) {
        revisions.cancelUnchanged(key, null);
        return;
      }
      if (record.intent != WriteIntent.load) rethrow;
      _diagnostics(
        WriterLogLevel.warning,
        'Wallet writer rebuilding interrupted missing store network=${key.network}',
      );
      revisions.requireRebuild(key);
      await _resumeRebuild(descriptor, record.issued);
      return;
    } on Object catch (error) {
      if (!allowRepairIntent || !isLiquidStatusConflict(error)) rethrow;
      revisions.requireRepair(key);
      final cachePath = await _rebuild(descriptor, record.issued);
      revisions.finish(
        key,
        needsSync: true,
        initializedDescriptor: descriptor,
        liquidCachePath: cachePath,
      );
      return;
    }
    try {
      final candidate = record.candidate;
      if (record.intent == WriteIntent.receive && candidate != null) {
        await session.revealAndPersist(candidate);
      }
      // Unknown sync completion still invalidates snapshots. It does not
      // unblock post-repair receive or produce any payment-seen receipt.
      revisions.finish(
        key,
        issued: _highestIndex(
          _highestIndex(record.issued, candidate),
          await session.lastIssuedIndex(),
        ),
        initializedDescriptor: descriptor,
        liquidCachePath: session.liquidCachePath,
      );
    } finally {
      session.close();
    }
  }

  Future<void> _resumeRebuild(
    PublicWalletDescriptor descriptor,
    int? issued,
  ) async {
    late NativeWriteSession session;
    try {
      session = await _sessions.open(descriptor, create: false);
    } on NativeStoreMissing {
      session = await _sessions.open(descriptor, create: true);
    }
    try {
      if (issued != null) await session.revealAndPersist(issued);
      revisions.finish(
        descriptor.key,
        needsSync: true,
        initializedDescriptor: descriptor,
        liquidCachePath: session.liquidCachePath,
      );
    } finally {
      session.close();
    }
  }

  Future<String?> _rebuild(
    PublicWalletDescriptor descriptor,
    int? issued,
  ) async {
    _diagnostics(
      WriterLogLevel.warning,
      'Wallet writer repair started network=${descriptor.key.network}',
    );
    await _sessions.delete(descriptor.key);
    final session = await _sessions.open(descriptor, create: true);
    try {
      if (issued != null) await session.revealAndPersist(issued);
      return session.liquidCachePath;
    } finally {
      session.close();
    }
  }

  int? _highestIndex(int? left, int? right) => left == null
      ? right
      : right == null
      ? left
      : math.max(left, right);

  Future<PublicWalletDescriptor> _descriptor(WalletKey key) async {
    final descriptor = _value(await _catalog.find(key));
    if (descriptor.key != key) {
      throw const _WriterFailure(TransactionSyncInvalidCatalogFailure());
    }
    final record = revisions.record(key);
    final previousHash = record?.descriptorHash;
    if (record?.state.lifecycle != WalletLifecycle.deleted &&
        previousHash != null &&
        previousHash != descriptorDigest(descriptor)) {
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
    if (!reportFailures || _failures[key] == failure.runtimeType) return;
    _failures[key] = failure.runtimeType;
    if (failure is TransactionSyncStorageFailure) {
      _diagnostics(
        WriterLogLevel.severe,
        'Wallet writer unexpected storage failure category=${failure.logCode}',
      );
    } else {
      _diagnostics(
        WriterLogLevel.warning,
        'Wallet writer operation unavailable network=${key.network} category=${failure.logCode}',
      );
    }
  }

  static T _value<T>(Result<T, TransactionSyncFailure> result) =>
      switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw _WriterFailure(failure),
      };

  TransactionSyncFailure _map(WalletKey key, Object error) {
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
