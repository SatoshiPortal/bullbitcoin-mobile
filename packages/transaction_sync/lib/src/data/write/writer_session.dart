import 'dart:math' as math;

import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/native_network_policy.dart';
import '../../domain/ports/wallet_catalog_port.dart';
import '../../domain/public_wallet_descriptor.dart';
import '../../domain/transaction_sync_failure.dart';
import '../../domain/wallet_key.dart';
import '../../domain/wallet_revision.dart';
import '../datasources/spend_gate_store_datasource.dart';
import '../lease_diagnostics.dart';
import '../native_store_paths.dart';
import 'native_write_session.dart';
import '../datasources/revision_store_datasource.dart';
import '../sqlite_wallet_revision_reader.dart';
import '../store_identity.dart';
import '../writer_diagnostics.dart';
import 'writer_lock.dart';
import 'writer_sync_operation.dart';

/// The single safety sequence of every native write, read here in order:
/// lock → generation and descriptor (hash against the store) → resume of an
/// interrupted intent → durable intent → native mutation → spend evidence →
/// revision → release, never by timeout. No retry follows a mutation.
///
/// Two entries share it: the app resolves descriptors from its catalog
/// ([WriterSession.app]); the sync worker supplies the descriptor it was given
/// ([WriterSession.worker]). Invoke inside the isolate doing native IO.
final class WriterSession {
  final String documentsDirectory;
  final RevisionStoreDatasource revisions;
  final SqliteWalletRevisionReader reader;
  final NativeWriteSessions sessions;
  final Future<Result<PublicWalletDescriptor, TransactionSyncFailure>> Function(
    WalletKey,
  )
  _resolve;
  final WriterDiagnosticSink diagnostics;
  final bool reportFailures;
  final LeaseScope leaseScope;
  final Map<WalletKey, Type> _failures = {};

  WriterSession.app({
    required this.documentsDirectory,
    required this.revisions,
    required this.reader,
    required this.sessions,
    required WalletCatalogPort catalog,
    this.diagnostics = persistWriterDiagnostic,
    this.reportFailures = true,
    this.leaseScope = LeaseScope.foreground,
  }) : _resolve = catalog.find;

  WriterSession.worker({
    required this.documentsDirectory,
    required this.revisions,
    required this.reader,
    required this.sessions,
    required PublicWalletDescriptor descriptor,
    required this.diagnostics,
    required this.leaseScope,
  }) : reportFailures = false,
       _resolve = ((key) async => key == descriptor.key
           ? Ok(descriptor)
           : const Err(TransactionSyncNotFoundFailure()));

  /// Creates a store, or adopts an existing one with [existingOnly].
  Future<Result<WriterOutcome, TransactionSyncFailure>> create(
    WalletKey key, {
    required int expectedGeneration,
    bool existingOnly = false,
  }) => run(key, expectedGeneration, WriteIntent.create, () async {
    final old = revisions.record(key);
    expectGeneration(old, expectedGeneration);
    final descriptor = await this.descriptor(key);
    if (existingOnly ||
        (old != null && old.state.lifecycle == WalletLifecycle.active)) {
      revisions.begin(key, WriteIntent.load);
      late NativeWriteSession session;
      var rebuilt = false;
      try {
        session = await sessions.open(descriptor, create: false);
      } on NativeStoreMissing {
        if (old == null || old.state.initializedSchema == 0) {
          cancelUnchanged(key, old);
          rethrow;
        }
        diagnostics(
          WriterLogLevel.warning,
          'Wallet writer rebuilding missing store network=${key.network}',
        );
        revisions.requireRebuild(key);
        session = await sessions.open(descriptor, create: true);
        rebuilt = true;
      }
      try {
        if (old?.issued case final issued? when rebuilt) {
          await session.revealAndPersist(issued);
        }
        final issued = highestIndex(
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
          cancelUnchanged(key, old);
          return WriterUnchanged(old.state.stamp);
        }
        return WriterCommitted(
          finish(
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
    final session = await sessions.open(descriptor, create: true);
    try {
      return WriterCommitted(
        finish(
          key,
          issued: highestIndex(old?.issued, await session.lastIssuedIndex()),
          initializedDescriptor: descriptor,
          liquidCachePath: session.liquidCachePath,
        ),
      );
    } finally {
      session.close();
    }
  });

  Future<Result<WriterOutcome, TransactionSyncFailure>> sync(
    WalletKey key, {
    required int expectedGeneration,
    required WriterSyncOperation operation,
    bool reconcile = true,
    Future<Result<void, TransactionSyncFailure>> Function()? preflight,
  }) => run(key, expectedGeneration, WriteIntent.sync, () async {
    final record = active(key, expectedGeneration);
    final descriptor = await this.descriptor(key);
    if (preflight != null) value(await preflight());
    SpendGateStoreDatasource? gates;
    if (key.network is BitcoinNetwork) {
      gates = openSpendGate();
      try {
        final tracked = gates.trackedInputs(descriptor);
        if (operation case final WriterSyncSpendObservation observer) {
          observer.trackSpendTransactions(tracked);
        }
        gates.requireValidation(key);
      } finally {
        gates.close();
      }
    }
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
        cancelUnchanged(key, record);
      } else {
        // Native work completed with an uncertain mutation: invalidate readers,
        // but never claim a successful sync or clear a prior repair barrier.
        final stamp = finish(key, syncFailed: true);
        diagnostics(
          WriterLogLevel.fine,
          'Writer revision invalidated generation=${stamp.generation} revision=${stamp.revision} reason=${(result as Err<void, TransactionSyncFailure>).failure.logCode}',
        );
      }
    }
    value(result);
    if (operation case WriterSyncSpendObservation(
      :final observedSpendTransactions,
      :final spendTransactionInputs,
      :final settledSpendTransactions,
    ) when key.network is BitcoinNetwork) {
      final observed = openSpendGate();
      try {
        observed.observed(descriptor, expectedGeneration, {
          ...observedSpendTransactions,
          ...settledSpendTransactions,
        }, inputs: spendTransactionInputs);
      } finally {
        observed.close();
      }
    }
    if (operation case WriterSyncChanges(
      hasChanges: false,
    ) when !record.needsSync && !record.state.syncFailed) {
      cancelUnchanged(key, record, syncSucceeded: true);
      return WriterUnchanged(record.state.stamp);
    }
    return WriterCommitted(finish(key, needsSync: false));
  }, reconcile: reconcile);

  /// Runs [operation] under one writer lock acquisition, after resuming any
  /// interrupted intent. Throw [WriterRefusal] to return a typed failure.
  Future<Result<T, TransactionSyncFailure>> run<T>(
    WalletKey key,
    int expectedGeneration,
    WriteIntent intent,
    Future<T> Function() operation, {
    bool allowRepairIntent = false,
    bool deleting = false,
    bool preparing = false,
    bool reconcile = true,
  }) async {
    final failure = nativeKeyFailure(key);
    if (failure != null) {
      _reportFailure(key, failure);
      return Err(failure);
    }
    final trace = LeaseDiagnostics(
      role: LeaseRole.writer,
      intent: preparing
          ? LeaseIntent.prepareReimport
          : switch (intent) {
              WriteIntent.create => LeaseIntent.create,
              WriteIntent.receive => LeaseIntent.receive,
              WriteIntent.delete => LeaseIntent.delete,
              WriteIntent.repair || WriteIntent.rebuild => LeaseIntent.repair,
              WriteIntent.load => LeaseIntent.reconcile,
              WriteIntent.sync => LeaseIntent.sync,
            },
      scope: leaseScope,
      sink: diagnostics,
    );
    final acquisition = await WriterLock.acquireWriter(
      documentsDirectory,
      key,
      diagnostics: trace,
    );
    if (acquisition case Err(:final failure)) {
      _reportFailure(key, failure);
      return Err(failure);
    }
    final lock = (acquisition as Ok<WriterLock, TransactionSyncFailure>).value;
    final watch = Stopwatch()..start();
    try {
      if (key.network is BitcoinNetwork &&
          intent != WriteIntent.receive &&
          intent != WriteIntent.sync) {
        _invalidateSpendGate(key);
      }
      final admitted = revisions.record(key);
      expectGeneration(admitted, expectedGeneration);
      if (!reconcile &&
          (admitted == null ||
              admitted.intent != null ||
              admitted.state.lifecycle != WalletLifecycle.active ||
              admitted.state.initializedSchema != writerSchemaVersion ||
              admitted.needsSync)) {
        trace.busy(
          admitted != null &&
                  admitted.state.initializedSchema != writerSchemaVersion
              ? LeaseBusySource.schemaGate
              : LeaseBusySource.lifecycleGate,
        );
        throw const WriterRefusal(TransactionSyncBusyFailure());
      }
      // Delete must remain possible for damaged stores: it supersedes an
      // unfinished write, but completes an existing tombstone without another
      // generation increment.
      if (reconcile &&
          (!deleting || revisions.record(key)?.intent == WriteIntent.delete)) {
        await _reconcile(key, allowRepairIntent: allowRepairIntent);
      }
      final value = await trace.run(operation);
      final stamp = revisions.record(key)?.state.stamp;
      _failures.remove(key);
      diagnostics(
        WriterLogLevel.fine,
        'Wallet writer finished intent=${intent.name} outcome=${preparing
            ? 'prepared'
            : value is WriterUnchanged
            ? 'unchanged'
            : 'committed'} network=${key.network} generation=${stamp?.generation} revision=${stamp?.revision} duration_ms=${watch.elapsedMilliseconds}',
      );
      return Ok(value);
    } on Object catch (error) {
      if (error is SqliteException && error.resultCode == 5) {
        trace.busy(LeaseBusySource.revisionRead);
      }
      final mapped = mapFailure(error);
      final failure = mapped is TransactionSyncNeedsRepairFailure
          ? TransactionSyncNeedsRepairFailure(
              revisions.record(key)?.state.stamp,
            )
          : mapped;
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
    if (key.network is BitcoinNetwork && record.intent != WriteIntent.receive) {
      _invalidateSpendGate(key);
    }
    diagnostics(
      WriterLogLevel.warning,
      'Wallet writer reconciling interrupted intent=${record.intent?.name} network=${key.network} generation=${record.state.stamp.generation} revision=${record.state.stamp.revision}',
    );
    if (record.intent == WriteIntent.delete) {
      await sessions.delete(key);
      finish(key);
      return;
    }
    final descriptor = await this.descriptor(key);
    if (record.intent == WriteIntent.rebuild) {
      await _resumeRebuild(descriptor, record.issued);
      return;
    }
    if (record.intent == WriteIntent.repair) {
      if (!allowRepairIntent) {
        throw const WriterRefusal(TransactionSyncNeedsRepairFailure());
      }
      final cachePath = await rebuild(descriptor, record.issued);
      finish(
        key,
        needsSync: true,
        initializedDescriptor: descriptor,
        liquidCachePath: cachePath,
      );
      return;
    }
    late NativeWriteSession session;
    try {
      session = await sessions.open(
        descriptor,
        create: record.intent == WriteIntent.create,
      );
    } on NativeStoreMissing {
      if (record.state.initializedSchema == 0 &&
          record.intent == WriteIntent.load) {
        cancelUnchanged(key, null);
        return;
      }
      if (record.intent != WriteIntent.load) rethrow;
      diagnostics(
        WriterLogLevel.warning,
        'Wallet writer rebuilding interrupted missing store network=${key.network}',
      );
      revisions.requireRebuild(key);
      await _resumeRebuild(descriptor, record.issued);
      return;
    } on Object catch (error) {
      if (!allowRepairIntent || !isLiquidStatusConflict(error)) rethrow;
      revisions.requireRepair(key);
      final cachePath = await rebuild(descriptor, record.issued);
      finish(
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
      finish(
        key,
        issued: highestIndex(
          highestIndex(record.issued, candidate),
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
      session = await sessions.open(descriptor, create: false);
    } on NativeStoreMissing {
      session = await sessions.open(descriptor, create: true);
    }
    try {
      if (issued != null) await session.revealAndPersist(issued);
      finish(
        descriptor.key,
        needsSync: true,
        initializedDescriptor: descriptor,
        liquidCachePath: session.liquidCachePath,
      );
    } finally {
      session.close();
    }
  }

  /// Erases and recreates the store, replaying [issued]. Call under [run].
  Future<String?> rebuild(
    PublicWalletDescriptor descriptor,
    int? issued,
  ) async {
    diagnostics(
      WriterLogLevel.warning,
      'Wallet writer repair started network=${descriptor.key.network}',
    );
    await sessions.delete(descriptor.key);
    final session = await sessions.open(descriptor, create: true);
    try {
      if (issued != null) await session.revealAndPersist(issued);
      return session.liquidCachePath;
    } finally {
      session.close();
    }
  }

  /// Commits the pending intent, then publishes the new state in this isolate.
  WalletRevision finish(
    WalletKey key, {
    int? issued,
    bool? needsSync,
    bool? syncFailed,
    PublicWalletDescriptor? initializedDescriptor,
    String? liquidCachePath,
  }) {
    final state = revisions.finish(
      key,
      issued: issued,
      needsSync: needsSync,
      syncFailed: syncFailed,
      initializedDescriptor: initializedDescriptor,
      liquidCachePath: liquidCachePath,
    );
    reader.publish(state);
    return state.stamp;
  }

  /// Clears a proven non-mutating intent and publishes the restored state.
  void cancelUnchanged(
    WalletKey key,
    RevisionRecord? previous, {
    bool syncSucceeded = false,
  }) {
    final state = revisions.cancelUnchanged(
      key,
      previous,
      syncSucceeded: syncSucceeded,
    );
    if (state != null) reader.publish(state);
  }

  /// The foreground provisioned the spend gate; it is never created here.
  SpendGateStoreDatasource openSpendGate() =>
      SpendGateStoreDatasource.openExisting(
        spendGateStorePath(documentsDirectory),
      );

  /// Recovery cannot silently forget protection when native metadata changes.
  void _invalidateSpendGate(WalletKey key) {
    if (key.network is! BitcoinNetwork) return;
    final gates = openSpendGate();
    try {
      gates.requireValidation(key);
    } finally {
      gates.close();
    }
  }

  int? highestIndex(int? left, int? right) => left == null
      ? right
      : right == null
      ? left
      : math.max(left, right);

  /// Resolves the descriptor and refuses one whose hash differs from the one
  /// the store was initialized with.
  Future<PublicWalletDescriptor> descriptor(WalletKey key) async {
    final descriptor = value(await _resolve(key));
    if (descriptor.key != key) {
      throw const WriterRefusal(TransactionSyncInvalidCatalogFailure());
    }
    final failure = nativeDescriptorFailure(descriptor);
    if (failure != null) throw WriterRefusal(failure);
    final record = revisions.record(key);
    final previousHash = record?.descriptorHash;
    if (record?.state.lifecycle != WalletLifecycle.deleted &&
        previousHash != null &&
        previousHash != descriptorDigest(descriptor)) {
      throw const WriterRefusal(TransactionSyncInvalidCatalogFailure());
    }
    return descriptor;
  }

  RevisionRecord active(WalletKey key, int generation) {
    final record = revisions.record(key);
    expectGeneration(record, generation);
    if (record == null || record.state.lifecycle != WalletLifecycle.active) {
      throw const WriterRefusal(TransactionSyncNotFoundFailure());
    }
    return record;
  }

  void expectGeneration(RevisionRecord? record, int generation) {
    if ((record?.state.stamp.generation ?? 0) != generation) {
      throw const WriterRefusal(TransactionSyncNotFoundFailure());
    }
  }

  void _reportFailure(WalletKey key, TransactionSyncFailure failure) {
    if (!reportFailures || _failures[key] == failure.runtimeType) return;
    _failures[key] = failure.runtimeType;
    if (failure is TransactionSyncStorageFailure) {
      diagnostics(
        WriterLogLevel.severe,
        'Wallet writer unexpected storage failure category=${failure.logCode}',
      );
    } else {
      diagnostics(
        WriterLogLevel.warning,
        'Wallet writer operation unavailable network=${key.network} category=${failure.logCode}',
      );
    }
  }

  static T value<T>(Result<T, TransactionSyncFailure> result) =>
      switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw WriterRefusal(failure),
      };

  /// Programmer [Error]s propagate; everything else becomes a typed failure.
  static TransactionSyncFailure mapFailure(Object error) {
    if (error is Error) throw error;
    if (error is WriterRefusal) return error.failure;
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

/// Thrown inside [WriterSession.run] to end the operation with [failure].
final class WriterRefusal implements Exception {
  final TransactionSyncFailure failure;
  const WriterRefusal(this.failure);
}
