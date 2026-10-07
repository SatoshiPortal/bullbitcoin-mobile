import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../domain/entities/recoverbull_network.dart';

part 'recoverbull_database.g.dart';

class RecoverbullState extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get serverUrlOverride => text().nullable()();
  BoolColumn get permissionGranted =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get attemptMonitoringEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get etag => text().nullable()();
  DateTimeColumn get lastSuccessfulCheckAt => dateTime().nullable()();
  DateTimeColumn get collectionStartedAt => dateTime().nullable()();
  IntColumn get consecutiveFailures =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUnavailabilityWarningAt => dateTime().nullable()();

  /// Until this instant the key server is known to lack `/attempts`, so it is
  /// not probed again; cleared whenever the server or the monitoring changes.
  DateTimeColumn get attemptsUnsupportedUntil => dateTime().nullable()();
  IntColumn get generation => integer().withDefault(const Constant(0))();
  IntColumn get revision => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (id = 1)',
    'CHECK (generation >= 0)',
    'CHECK (revision >= 0)',
    'CHECK (consecutive_failures >= 0)',
  ];
}

/// Encrypted-backup status of one Bitcoin network. A missing row means no
/// backup was ever recorded on that network.
class RecoverbullBackupStatus extends Table {
  /// A [RecoverBullNetwork] name.
  TextColumn get network => text()();
  DateTimeColumn get lastEncryptedBackupAt => dateTime().nullable()();
  DateTimeColumn get lastVerifiedEncryptedBackupAt => dateTime().nullable()();

  /// Set when this row was seeded in place of an archived corrupt database:
  /// the timestamps above are then unknown rather than absent, until the next
  /// backup on this network is stored or verified.
  BoolColumn get statusLost => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {network};

  @override
  List<String> get customConstraints => [
    "CHECK (network IN ('mainnet', 'testnet'))",
  ];
}

class RecoverbullMonitoredBackup extends Table {
  BlobColumn get digest =>
      blob().customConstraint('NOT NULL CHECK (length(digest) = 32)')();
  IntColumn get expectedServerDistinctCandidateTotal =>
      integer().withDefault(const Constant(0))();
  IntColumn get currentWindow => integer().withDefault(const Constant(0))();
  IntColumn get lastWarningWindow => integer().nullable()();
  IntColumn get rowRevision => integer().withDefault(const Constant(0))();
  TextColumn get origin => text().withDefault(const Constant('created'))();

  /// SHA-256 (hex) of the normalized Google account e-mail; the address
  /// itself is never stored.
  TextColumn get driveAccountHash => text().nullable()();
  TextColumn get driveFileId => text().nullable()();
  DateTimeColumn get driveFileCreatedAt => dateTime().nullable()();
  DateTimeColumn get driveFileModifiedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {digest};

  @override
  List<String> get customConstraints => [
    'CHECK (expected_server_distinct_candidate_total >= 0)',
    'CHECK (current_window >= 0)',
    'CHECK (last_warning_window IS NULL OR last_warning_window >= 0)',
    'CHECK (row_revision >= 0)',
  ];
}

class RecoverbullDriveBackupCache extends Table {
  /// SHA-256 (hex) of the normalized Google account e-mail.
  TextColumn get accountHash => text()();
  TextColumn get driveFileId => text()();
  BlobColumn get backupDigest => blob()();
  DateTimeColumn get driveFileCreatedAt => dateTime()();
  DateTimeColumn get driveFileModifiedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {accountHash, driveFileId};
}

/// Attempt alerts the user dismissed, by alert identity. Only identities
/// scoped to an attempt window are recorded, so a later window alerts again.
class RecoverbullAcknowledgedAlert extends Table {
  TextColumn get identity => text()();
  DateTimeColumn get acknowledgedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {identity};
}

@DriftDatabase(
  tables: [
    RecoverbullState,
    RecoverbullBackupStatus,
    RecoverbullMonitoredBackup,
    RecoverbullDriveBackupCache,
    RecoverbullAcknowledgedAlert,
  ],
)
final class RecoverBullDatabase extends _$RecoverBullDatabase {
  static const schema = 1;
  final bool initialPermissionGranted;
  final String? initialServerUrlOverride;
  final bool initialBackupStatusLost;

  RecoverBullDatabase._(
    super.executor, {
    this.initialPermissionGranted = false,
    this.initialServerUrlOverride,
    this.initialBackupStatusLost = false,
  });

  factory RecoverBullDatabase.open(
    String path, {
    bool initialPermissionGranted = false,
    String? initialServerUrlOverride,
    bool initialBackupStatusLost = false,
  }) => RecoverBullDatabase._(
    NativeDatabase.createInBackground(
      File(path),
      setup: (database) {
        database.execute('PRAGMA busy_timeout = 2000;');
        database.execute('PRAGMA journal_mode = WAL;');
        database.execute('PRAGMA synchronous = FULL;');
        database.execute('PRAGMA secure_delete = ON;');
      },
    ),
    initialPermissionGranted: initialPermissionGranted,
    initialServerUrlOverride: initialServerUrlOverride,
    initialBackupStatusLost: initialBackupStatusLost,
  );

  factory RecoverBullDatabase.forTesting(QueryExecutor executor) =
      RecoverBullDatabase._;

  @override
  int get schemaVersion => schema;

  Future<void> ensureState({
    bool initialPermissionGranted = false,
    String? initialServerUrlOverride,
    bool initialBackupStatusLost = false,
  }) async {
    await transaction(() async {
      await into(recoverbullState).insert(
        RecoverbullStateCompanion(
          id: const Value(1),
          permissionGranted: Value(initialPermissionGranted),
          serverUrlOverride: Value(initialServerUrlOverride),
          attemptMonitoringEnabled: const Value(true),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      if (initialBackupStatusLost) {
        for (final network in RecoverBullNetwork.values) {
          await into(recoverbullBackupStatus).insert(
            RecoverbullBackupStatusCompanion.insert(
              network: network.name,
              statusLost: const Value(true),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
      if (initialServerUrlOverride != null) {
        await (update(recoverbullState)..where(
              (state) => state.id.equals(1) & state.serverUrlOverride.isNull(),
            ))
            .write(
              RecoverbullStateCompanion(
                serverUrlOverride: Value(initialServerUrlOverride),
              ),
            );
      }
    });
  }

  /// Opens the connection, verifies the file before writing to it, then seeds
  /// the singleton state row. `PRAGMA integrity_check` returns one row per
  /// problem, so anything but a single `ok` row is reported as corruption.
  Future<void> forceOpen() async {
    final integrity = await customSelect('PRAGMA integrity_check').get();
    if (integrity.length != 1 ||
        integrity.single.read<String>('integrity_check') != 'ok') {
      throw const RecoverBullDatabaseIntegrityException();
    }
    await ensureState(
      initialPermissionGranted: initialPermissionGranted,
      initialServerUrlOverride: initialServerUrlOverride,
      initialBackupStatusLost: initialBackupStatusLost,
    );
  }

  Future<RecoverbullBackupStatusData?> fetchBackupStatus(
    RecoverBullNetwork network,
  ) => (select(
    recoverbullBackupStatus,
  )..where((row) => row.network.equals(network.name))).getSingleOrNull();

  Future<void> markEncryptedBackupStored(RecoverBullNetwork network) async {
    await into(recoverbullBackupStatus).insertOnConflictUpdate(
      RecoverbullBackupStatusCompanion.insert(
        network: network.name,
        lastEncryptedBackupAt: Value(DateTime.now().toUtc()),
        lastVerifiedEncryptedBackupAt: const Value(null),
        statusLost: const Value(false),
      ),
    );
  }

  Future<void> markEncryptedBackupVerified(RecoverBullNetwork network) async {
    await into(recoverbullBackupStatus).insertOnConflictUpdate(
      RecoverbullBackupStatusCompanion.insert(
        network: network.name,
        lastVerifiedEncryptedBackupAt: Value(DateTime.now().toUtc()),
        statusLost: const Value(false),
      ),
    );
  }
}

/// Thrown by [RecoverBullDatabase.forceOpen] when SQLite reports the file as
/// structurally damaged.
final class RecoverBullDatabaseIntegrityException implements Exception {
  const RecoverBullDatabaseIntegrityException();

  @override
  String toString() => 'RecoverBullDatabaseIntegrityException';
}
