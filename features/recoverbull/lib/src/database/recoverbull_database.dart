import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'recoverbull_database.g.dart';

class RecoverbullState extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get serverUrlOverride => text().nullable()();
  BoolColumn get permissionGranted =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get attemptMonitoringEnabled =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastEncryptedBackupAt => dateTime().nullable()();
  DateTimeColumn get lastVerifiedEncryptedBackupAt => dateTime().nullable()();
  TextColumn get etag => text().nullable()();
  DateTimeColumn get lastSuccessfulCheckAt => dateTime().nullable()();
  DateTimeColumn get collectionStartedAt => dateTime().nullable()();
  IntColumn get consecutiveFailures =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUnavailabilityWarningAt => dateTime().nullable()();
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

class RecoverbullMonitoredBackup extends Table {
  BlobColumn get digest =>
      blob().customConstraint('NOT NULL CHECK (length(digest) = 32)')();
  IntColumn get expectedServerDistinctCandidateTotal =>
      integer().withDefault(const Constant(0))();
  IntColumn get currentWindow => integer().withDefault(const Constant(0))();
  IntColumn get lastWarningWindow => integer().nullable()();
  IntColumn get rowRevision => integer().withDefault(const Constant(0))();
  TextColumn get origin => text().withDefault(const Constant('created'))();
  TextColumn get driveAccount => text().nullable()();
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
  TextColumn get account => text()();
  TextColumn get driveFileId => text()();
  BlobColumn get backupDigest => blob()();
  DateTimeColumn get driveFileCreatedAt => dateTime()();
  DateTimeColumn get driveFileModifiedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {account, driveFileId};
}

@DriftDatabase(
  tables: [
    RecoverbullState,
    RecoverbullMonitoredBackup,
    RecoverbullDriveBackupCache,
  ],
)
final class RecoverBullDatabase extends _$RecoverBullDatabase {
  static const schema = 1;
  final bool initialPermissionGranted;

  RecoverBullDatabase._(
    super.executor, {
    this.initialPermissionGranted = false,
  });

  factory RecoverBullDatabase.open(
    String path, {
    bool initialPermissionGranted = false,
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
  );

  factory RecoverBullDatabase.forTesting(QueryExecutor executor) =
      RecoverBullDatabase._;

  @override
  int get schemaVersion => schema;

  Future<void> ensureState({bool initialPermissionGranted = false}) async {
    await transaction(() async {
      await into(recoverbullState).insert(
        RecoverbullStateCompanion(
          id: const Value(1),
          permissionGranted: Value(initialPermissionGranted),
          attemptMonitoringEnabled: const Value(true),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Future<void> forceOpen() async {
    await customSelect('SELECT 1').get();
    await ensureState(initialPermissionGranted: initialPermissionGranted);
    final result = await customSelect('PRAGMA integrity_check').getSingle();
    if (result.read<String>('integrity_check') != 'ok') {
      throw StateError('database integrity check failed');
    }
  }

  Future<void> markEncryptedBackupStored() async {
    await update(recoverbullState).write(
      RecoverbullStateCompanion(
        lastEncryptedBackupAt: Value(DateTime.now().toUtc()),
        lastVerifiedEncryptedBackupAt: const Value(null),
      ),
    );
  }

  Future<void> markEncryptedBackupVerified() async {
    await update(recoverbullState).write(
      RecoverbullStateCompanion(
        lastVerifiedEncryptedBackupAt: Value(DateTime.now().toUtc()),
      ),
    );
  }
}
