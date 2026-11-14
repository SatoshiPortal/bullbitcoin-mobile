import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/native_network_policy.dart';
import '../domain/ports/read_admission_port.dart';
import '../domain/ports/reserved_address_port.dart';
import '../domain/ports/wallet_catalog_port.dart';
import '../domain/repositories/wallet_writer_repository.dart';
import '../domain/transaction_sync_failure.dart';
import '../domain/wallet_key.dart';
import '../domain/wallet_revision.dart';
import 'lease_diagnostics.dart';
import 'native_write_session.dart';
import 'revision_store_datasource.dart';
import 'sqlite_wallet_revision_reader.dart';
import 'writer_lock.dart';
import 'writer_session.dart';

/// The app's lifecycle writer: each operation runs through [WriterSession],
/// which resolves descriptors from the catalog. Invoke inside the isolate
/// doing native IO. The caller owns the shared RevisionStoreDatasource and subscribes
/// before reading. No method times out native work.
final class NativeWalletWriterRepository
    implements WalletWriterRepository, ReadAdmissionPort {
  final WriterSession _session;
  final WalletCatalogPort _catalog;
  final ReservedAddressPort _reserved;

  NativeWalletWriterRepository({
    required String documentsDirectory,
    required RevisionStoreDatasource revisions,
    required SqliteWalletRevisionReader reader,
    required WalletCatalogPort catalog,
    required ReservedAddressPort reservedAddresses,
    LeaseScope leaseScope = LeaseScope.foreground,
  }) : this.withSessions(
         documentsDirectory: documentsDirectory,
         revisions: revisions,
         reader: reader,
         catalog: catalog,
         reservedAddresses: reservedAddresses,
         sessions: SdkWriteSessions(documentsDirectory),
         leaseScope: leaseScope,
       );

  @visibleForTesting
  NativeWalletWriterRepository.withSessions({
    required String documentsDirectory,
    required RevisionStoreDatasource revisions,
    required SqliteWalletRevisionReader reader,
    required WalletCatalogPort catalog,
    required ReservedAddressPort reservedAddresses,
    required NativeWriteSessions sessions,
    LeaseScope leaseScope = LeaseScope.foreground,
  }) : _catalog = catalog,
       _reserved = reservedAddresses,
       _session = WriterSession.app(
         documentsDirectory: documentsDirectory,
         revisions: revisions,
         reader: reader,
         sessions: sessions,
         catalog: catalog,
         leaseScope: leaseScope,
       );

  RevisionStoreDatasource get revisions => _session.revisions;

  /// Re-import reserves the next generation before publishing a new catalog
  /// row, so startup cannot mistake it for the row of an interrupted deletion.
  @override
  @useResult
  Future<Result<WriterOutcome, TransactionSyncFailure>> prepareReimport(
    WalletKey key, {
    required int expectedGeneration,
  }) => _session.run(key, expectedGeneration, WriteIntent.create, () async {
    final old = revisions.record(key);
    _session.expectGeneration(old, expectedGeneration);
    if (old == null || old.state.lifecycle != WalletLifecycle.deleted) {
      LeaseDiagnostics.current?.busy(LeaseBusySource.lifecycleGate);
      throw const WriterRefusal(TransactionSyncBusyFailure());
    }
    switch (await _catalog.find(key)) {
      case Err(failure: TransactionSyncNotFoundFailure()):
        break;
      case Err(:final failure):
        throw WriterRefusal(failure);
      case Ok():
        LeaseDiagnostics.current?.busy(LeaseBusySource.lifecycleGate);
        throw const WriterRefusal(TransactionSyncBusyFailure());
    }
    revisions.begin(key, WriteIntent.create);
    final prepared = revisions.record(key);
    if (prepared == null) throw StateError('Missing prepared generation');
    return WriterUnchanged(prepared.state.stamp);
  }, preparing: true);

  @override
  @useResult
  Future<Result<WriterOutcome, TransactionSyncFailure>> create(
    WalletKey key, {
    required int expectedGeneration,
    bool existingOnly = false,
  }) => _session.create(
    key,
    expectedGeneration: expectedGeneration,
    existingOnly: existingOnly,
  );

  @override
  @useResult
  Future<Result<ReceiveAddressIssued, TransactionSyncFailure>> receive(
    WalletKey key, {
    required int expectedGeneration,
    bool advance = false,
  }) => _session.run(key, expectedGeneration, WriteIntent.receive, () async {
    final record = _session.active(key, expectedGeneration);
    if (record.needsSync) {
      throw const WriterRefusal(TransactionSyncNeedsRepairFailure());
    }
    final descriptor = await _session.descriptor(key);
    revisions.begin(key, WriteIntent.receive);
    final session = await _session.sessions.open(descriptor, create: false);
    try {
      final nativeIssued = await session.lastIssuedIndex();
      final highWater = math.max(record.issued ?? -1, nativeIssued ?? -1);
      var index = math.max(
        advance ? highWater + 1 : highWater,
        await session.firstUnusedIndex(),
      );
      while (index < 0x80000000) {
        final address = await session.address(index);
        final reserved = WriterSession.value(
          await _reserved.isReserved(key, address),
        );
        if (!reserved && !await session.isUsed(index, address)) {
          // Reserve before native mutation. Reconciliation completes this
          // candidate; the next call checks reservations and usage again.
          revisions.reserveReceive(key, index);
          await session.revealAndPersist(index);
          final revision = _session.finish(key, issued: index);
          return ReceiveAddressIssued(revision, address: address, index: index);
        }
        index++;
      }
      throw const WriterRefusal(TransactionSyncStorageFailure());
    } finally {
      session.close();
    }
  });

  @override
  @useResult
  Future<Result<WriterOutcome, TransactionSyncFailure>> delete(
    WalletKey key, {
    required int expectedGeneration,
  }) => _session.run(key, expectedGeneration, WriteIntent.delete, () async {
    final record = revisions.record(key);
    _session.expectGeneration(record, expectedGeneration);
    if (record != null && record.state.lifecycle == WalletLifecycle.deleted) {
      return WriterUnchanged(record.state.stamp);
    }
    revisions.begin(key, WriteIntent.delete);
    await _session.sessions.delete(key);
    return WriterCommitted(_session.finish(key));
  }, deleting: true);

  /// Repair is explicit and only erases a store after the precise LWK conflict.
  /// It keeps issued metadata and requires a successful sync before receive.
  @override
  @useResult
  Future<Result<WriterOutcome, TransactionSyncFailure>> repair(
    WalletKey key, {
    required int expectedGeneration,
  }) => _session.run(key, expectedGeneration, WriteIntent.repair, () async {
    final record = _session.active(key, expectedGeneration);
    if (key.network is! LiquidNetwork) {
      throw const WriterRefusal(TransactionSyncUnsupportedNetworkFailure());
    }
    final descriptor = await _session.descriptor(key);
    revisions.begin(key, WriteIntent.load);
    try {
      final session = await _session.sessions.open(descriptor, create: false);
      try {
        return WriterCommitted(
          _session.finish(
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
    final cachePath = await _session.rebuild(descriptor, record.issued);
    return WriterCommitted(
      _session.finish(
        key,
        needsSync: true,
        initializedDescriptor: descriptor,
        liquidCachePath: cachePath,
      ),
    );
  }, allowRepairIntent: true);

  @override
  @useResult
  Future<Result<ReadLease, TransactionSyncFailure>> acquire(
    WalletKey key,
  ) async {
    final failure = nativeKeyFailure(key);
    if (failure != null) return Err(failure);
    final trace =
        LeaseDiagnostics.current ??
        LeaseDiagnostics(
          role: LeaseRole.reader,
          intent: LeaseIntent.snapshot,
          scope: _session.leaseScope,
          sink: _session.diagnostics,
        );
    final acquisition = WriterLock.acquire(
      _session.documentsDirectory,
      key,
      diagnostics: trace,
    );
    if (acquisition case Err(:final failure)) {
      return Err(failure);
    }
    final lock = (acquisition as Ok<WriterLock, TransactionSyncFailure>).value;
    try {
      final record = revisions.record(key);
      if (record == null || record.state.lifecycle == WalletLifecycle.deleted) {
        throw const WriterRefusal(TransactionSyncNotFoundFailure());
      }
      if (record.state.lifecycle != WalletLifecycle.active ||
          record.state.initializedSchema != writerSchemaVersion) {
        trace.busy(
          record.state.lifecycle != WalletLifecycle.active
              ? LeaseBusySource.lifecycleGate
              : LeaseBusySource.schemaGate,
        );
        throw const WriterRefusal(TransactionSyncBusyFailure());
      }
      if (record.needsSync) {
        throw const WriterRefusal(TransactionSyncNeedsRepairFailure());
      }
      return Ok(_ReadLease(lock, record.state.stamp));
    } on Object catch (error) {
      lock.release();
      if (error is SqliteException && error.resultCode == 5) {
        trace.busy(LeaseBusySource.revisionRead);
      }
      return Err(WriterSession.mapFailure(error));
    }
  }
}

final class _ReadLease implements ReadLease {
  final WriterLock _lock;
  @override
  final WalletRevision revision;
  _ReadLease(this._lock, this.revision);
  @override
  Future<void> release() async => _lock.release();
}
