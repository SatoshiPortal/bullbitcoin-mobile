import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/ports/reserved_address_port.dart';
import '../domain/ports/wallet_catalog_port.dart';
import '../domain/ports/wallet_revision_reader_port.dart';
import '../domain/repositories/wallet_writer_repository.dart';
import '../domain/wallet_revision.dart';
import '../read/persisted_wallet_readiness.dart';
import '../read/wallet_snapshot_reader.dart';
import 'bitcoin_spend_gate.dart';
import 'bitcoin_spend_gate_store.dart';
import 'native_store_paths.dart';
import 'native_wallet_writer_repository.dart';
import 'revision_store.dart';
import 'sqlite_wallet_revision_reader.dart';

/// What the foreground app uses. Only [openForeground] creates the package
/// stores; it does so before any sync pass can run.
final class ForegroundStores {
  final String documentsDirectory;
  final WalletWriterRepository writer;
  final SqliteWalletRevisionReader _revisions;
  final WalletSnapshotReader reader;
  final BitcoinSpendGate spendGate;
  final RevisionStore _store;
  bool _recovering;

  ForegroundStores._(
    this.documentsDirectory,
    this.writer,
    this._revisions,
    this.reader,
    this.spendGate,
    this._store,
    this._recovering,
  );

  WalletRevisionReaderPort get revisions => _revisions;

  /// Every state this isolate commits or reads, for all wallets.
  Stream<WalletRevisionState> get changes => _revisions.changes;

  /// Revision metadata was quarantined: adopt existing native stores only,
  /// then call [completeRecovery] once every catalog wallet has an outcome.
  /// No Bitcoin spend is admitted meanwhile.
  bool get recoveredMetadata => _recovering;

  /// Invalidates every retained spend observation, then lifts the recovery
  /// barrier. In that order, so no obligation survives unverified.
  void completeRecovery() {
    final gates = BitcoinSpendGateStore.openExisting(
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
    try {
      await _revisions.close();
    } finally {
      _store.close();
    }
  }
}

/// What background code may use: it never creates nor migrates a store.
final class ExistingStores {
  final SqliteWalletRevisionReader _revisions;
  final RevisionStore _store;

  ExistingStores._(this._revisions, this._store);

  WalletRevisionReaderPort get revisions => _revisions;

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
ForegroundStores openForeground({
  required String documentsDirectory,
  required WalletCatalogPort catalog,
  required ReservedAddressPort reservedAddresses,
}) {
  final store = _openOrQuarantine(documentsDirectory);
  try {
    try {
      BitcoinSpendGateStore.provision(spendGateStorePath(documentsDirectory));
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
    return ForegroundStores._(
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
      BitcoinSpendGate(
        revisions: store,
        documentsDirectory: documentsDirectory,
        catalog: catalog,
      ),
      store,
      File(recoveryMarkerPath(documentsDirectory)).existsSync(),
    );
  } on Object {
    store.close();
    rethrow;
  }
}

/// Throws [RevisionStoreUnavailable] unless the foreground created the store
/// at the current version.
ExistingStores openExisting(String documentsDirectory) {
  final store = RevisionStore.openExisting(
    revisionStorePath(documentsDirectory),
  );
  return ExistingStores._(SqliteWalletRevisionReader(store), store);
}

RevisionStore _openOrQuarantine(String documentsDirectory) {
  final path = revisionStorePath(documentsDirectory);
  try {
    return RevisionStore.openForeground(path);
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
  File(
    recoveryMarkerPath(documentsDirectory),
  ).writeAsStringSync('existing-only\n', flush: true);
  final suffix = '.corrupt-${DateTime.now().toUtc().microsecondsSinceEpoch}';
  for (final sidecar in ['', '-wal', '-shm']) {
    final file = File('$path$sidecar');
    if (file.existsSync()) file.renameSync('$path$sidecar$suffix');
  }
  log.warning('Wallet revision metadata quarantined category=corrupt');
  return RevisionStore.openForeground(path);
}
