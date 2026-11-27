import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/ports/freeze_store_port.dart';
import '../../domain/ports/input_reservation_port.dart';
import '../../domain/ports/funding_reservation_port.dart';
import '../../domain/ports/read_admission_port.dart';
import '../input_reservations.dart';
import '../../domain/ports/reserved_address_port.dart';
import '../../domain/ports/wallet_catalog_port.dart';
import '../../domain/ports/wallet_connection_port.dart';
import '../../domain/ports/wallet_revision_reader_port.dart';
import '../../domain/repositories/wallet_writer_repository.dart';
import '../../domain/wallet_revision.dart';
import '../../domain/wallet_key.dart';
import '../../domain/sync_failure.dart';
import '../read/persisted_wallet_readiness.dart';
import '../read/wallet_snapshot_reader.dart';
import 'bitcoin_spend_gate.dart';
import '../datasources/spend_gate_store_datasource.dart';
import '../native_store_paths.dart';
import 'native_wallet_writer_repository.dart';
import 'native_write_session.dart';
import '../datasources/revision_store_datasource.dart';
import '../sqlite_wallet_revision_reader.dart';
import '../freeze_authority.dart';
import 'spend/native_spend.dart';
import 'spend/spend_writer.dart';
import 'writer_session.dart';

/// What the foreground app uses. Only [openForeground] creates the package
/// stores; it does so before any sync pass can run.
final class ForegroundStores {
  final String documentsDirectory;
  final NativeWalletWriterRepository _writer;
  final SqliteWalletRevisionReader _revisions;

  /// Hydrates native handles for sync's own projections; never lent out.
  @internal
  final WalletSnapshotReader reader;
  final BitcoinSpendGate spendGate;

  /// The freezes, kept by the app. Spend construction checks its effective
  /// inputs against [FreezeAuthority.forbiddenInputs], under
  /// [FreezeAuthority.guard] at broadcast.
  final FreezeAuthority freezes;

  /// Payjoin's reservations, read to check the inputs of every spend.
  final InputReservationPort inputReservations;

  /// Builds, checks and broadcasts native spends.
  final SpendWriter spend;
  final RevisionStoreDatasource _store;
  bool _recovering;
  bool _closed = false;

  ForegroundStores._(
    this.documentsDirectory,
    this._writer,
    this._revisions,
    this.reader,
    this.spendGate,
    this.freezes,
    this.inputReservations,
    this.spend,
    this._store,
    this._recovering,
  );

  WalletRevisionReaderPort get revisions => _revisions;
  WalletWriterRepository get writer => _writer;

  @internal
  Future<Result<ReadLease, SyncFailure>> acquireExistingRead(WalletKey key) =>
      _writer.acquire(key, existingOnly: true);

  /// Read only the already-open SQLite connection, without publishing a
  /// revision event or calling any recovery or native-store code.
  @internal
  Result<WalletRevisionState, SyncFailure> retainedRevision(WalletKey key) {
    if (_closed || _recovering) return const Err(SyncClosedFailure());
    try {
      final record = _store.record(key);
      if (record == null || record.state.lifecycle == WalletLifecycle.deleted) {
        return const Err(SyncNotFoundFailure());
      }
      if (record.intent != null ||
          record.state.lifecycle != WalletLifecycle.active) {
        return const Err(SyncBusyFailure());
      }
      return Ok(record.state);
    } on SqliteException catch (error) {
      return Err(
        error.resultCode == 5
            ? const SyncBusyFailure()
            : const SyncStorageFailure(),
      );
    }
  }

  /// Every state this isolate commits or reads, for all wallets.
  Stream<WalletRevisionState> get changes => _revisions.changes;

  /// Revision metadata was quarantined: adopt existing native stores only,
  /// then call [completeRecovery] once every catalog wallet has an outcome.
  /// No Bitcoin spend is admitted meanwhile.
  bool get recoveredMetadata => _recovering;

  /// Invalidates every retained spend observation, then lifts the recovery
  /// barrier. In that order, so no obligation survives unverified.
  void completeRecovery() {
    final gates = SpendGateStoreDatasource.openExisting(
      spendGateStorePath(documentsDirectory),
    );
    try {
      gates.requireRecoveryValidation();
    } finally {
      gates.close();
    }
    File(recoveryMarkerPath(documentsDirectory)).deleteSync();
    _recovering = false;
  }

  Future<void> close() async {
    _closed = true;
    await spend.close();
    try {
      await _revisions.close();
    } finally {
      try {
        await freezes.close();
      } finally {
        _store.close();
      }
    }
  }
}

/// What background code may use: it never creates nor migrates a store.
final class ExistingStores {
  final SqliteWalletRevisionReader _revisions;
  final RevisionStoreDatasource _store;

  ExistingStores._(this._revisions, this._store);

  WalletRevisionReaderPort get revisions => _revisions;

  /// Every state this isolate reads, for all wallets.
  Stream<WalletRevisionState> get changes => _revisions.changes;

  Future<void> close() async {
    try {
      await _revisions.close();
    } finally {
      _store.close();
    }
  }
}

/// Opens or creates the revision store and the spend gate, quarantining
/// unreadable revision metadata, and assembles the writer and reader.
/// [freezes] is the app's store; nothing reads it here.
ForegroundStores openForeground({
  required String documentsDirectory,
  required WalletCatalogPort catalog,
  required ReservedAddressPort reservedAddresses,
  required FreezeStorePort freezes,
  required InputReservationPort inputReservations,
  FundingReservationPort? fundingReservations,
  required WalletConnectionPort connections,
  @visibleForTesting NativeSpendSessions? spendSessions,
  @visibleForTesting SpendTransport? spendTransport,
}) {
  final store = _openOrQuarantine(documentsDirectory);
  try {
    try {
      SpendGateStoreDatasource.provision(
        spendGateStorePath(documentsDirectory),
      );
    } on BitcoinSpendGateUnavailable {
      // Bitcoin spends and writes then fail closed; Liquid and reads go on.
      log.warning('Bitcoin spend gate unavailable category=storage');
    }
    final revisions = SqliteWalletRevisionReader(store);
    final writer = NativeWalletWriterRepository(
      documentsDirectory: documentsDirectory,
      revisions: store,
      reader: revisions,
      catalog: catalog,
      reservedAddresses: reservedAddresses,
    );
    final gate = BitcoinSpendGate(
      revisions: store,
      documentsDirectory: documentsDirectory,
      catalog: catalog,
    );
    final authority = FreezeAuthority(freezes);
    final reservations = CombinedInputReservations(
      inputReservations,
      fundingReservations,
    );
    late final ForegroundStores stores;
    stores = ForegroundStores._(
      documentsDirectory,
      writer,
      revisions,
      WalletSnapshotReader(
        documentsDirectory: documentsDirectory,
        readiness: PersistedWalletReadiness(store),
        requiredSchemaVersion: writerSchemaVersion,
        revisions: revisions,
        liquidAdmission: writer,
      ),
      gate,
      authority,
      reservations,
      SpendWriter(
        session: WriterSession.app(
          documentsDirectory: documentsDirectory,
          revisions: store,
          reader: revisions,
          sessions: SdkWriteSessions(documentsDirectory),
          catalog: catalog,
        ),
        gate: gate,
        freezes: authority,
        reservations: reservations,
        fundingReservations: fundingReservations,
        natives: spendSessions ?? SdkSpendSessions(documentsDirectory),
        send: spendTransport ?? SpendWriter.transport(connections),
        closed: () => stores._closed,
      ),
      store,
      File(recoveryMarkerPath(documentsDirectory)).existsSync(),
    );
    return stores;
  } on Object {
    store.close();
    rethrow;
  }
}

/// Throws [RevisionStoreUnavailable] unless the foreground created the store
/// at the current version.
ExistingStores openExisting(String documentsDirectory) {
  final store = RevisionStoreDatasource.openExisting(
    revisionStorePath(documentsDirectory),
  );
  return ExistingStores._(SqliteWalletRevisionReader(store), store);
}

RevisionStoreDatasource _openOrQuarantine(String documentsDirectory) {
  final path = revisionStorePath(documentsDirectory);
  try {
    return RevisionStoreDatasource.openForeground(path);
  } on Object catch (error) {
    // A locked, unwritable or full disk is not corruption. Preserve it intact.
    final damaged =
        error is RevisionStoreUnavailable ||
        (error is SqliteException &&
            (error.resultCode == 11 || error.resultCode == 26));
    if (!damaged) rethrow;
  }
  // Persist the adoption-only policy before replacing damaged metadata.
  // A later restart must not treat an unadopted row as a fresh wallet.
  File(recoveryMarkerPath(documentsDirectory))
      .writeAsStringSync('existing-only\n', flush: true);
  final suffix = '.corrupt-${DateTime.now().toUtc().microsecondsSinceEpoch}';
  for (final sidecar in ['', '-wal', '-shm']) {
    final file = File('$path$sidecar');
    if (file.existsSync()) file.renameSync('$path$sidecar$suffix');
  }
  log.warning('Wallet revision metadata quarantined category=corrupt');
  return RevisionStoreDatasource.openForeground(path);
}
