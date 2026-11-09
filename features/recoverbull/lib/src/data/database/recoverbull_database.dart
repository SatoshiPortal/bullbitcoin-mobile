import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../domain/recoverbull_server_url.dart';

part 'recoverbull_database.g.dart';

class RecoverbullState extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get server =>
      text().withDefault(const Constant(recoverBullDefaultServerUrl))();
  BoolColumn get permissionGranted =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get monitoringEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get legacyImportComplete =>
      boolean().withDefault(const Constant(false))();
  IntColumn get monitoringRevision =>
      integer().withDefault(const Constant(0))();
  IntColumn get generation => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (id = 1)',
    'CHECK (generation >= 0)',
  ];
}

class RecoverbullBackupStatus extends Table {
  TextColumn get network => text()();
  TextColumn get fingerprint => text()();
  BlobColumn get vaultDigest =>
      blob().customConstraint('NOT NULL CHECK (length(vault_digest) = 32)')();
  DateTimeColumn get storedAt => dateTime().nullable()();
  DateTimeColumn get verifiedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {network, fingerprint, vaultDigest};
}

class RecoverbullMonitoredVaults extends Table {
  TextColumn get server => text()();
  BlobColumn get digest =>
      blob().customConstraint('NOT NULL CHECK (length(digest) = 32)')();
  IntColumn get anchorRequests => integer().nullable()();
  IntColumn get observedRequests => integer().nullable()();
  IntColumn get window => integer().nullable()();
  IntColumn get collection => integer().nullable()();
  IntColumn get ownRequests => integer().withDefault(const Constant(0))();
  BoolColumn get unknown => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {server, digest};
}

class RecoverbullOwnOperations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get server => text()();
  BlobColumn get digest =>
      blob().customConstraint('NOT NULL CHECK (length(digest) = 32)')();
}

class RecoverbullAlerts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get server => text()();
  BlobColumn get digest =>
      blob().customConstraint('NOT NULL CHECK (length(digest) = 32)')();
  IntColumn get window => integer()();
  TextColumn get kind => text()();
  BoolColumn get acknowledged => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {server, digest, window, kind},
  ];
}

@DriftDatabase(
  tables: [
    RecoverbullState,
    RecoverbullBackupStatus,
    RecoverbullMonitoredVaults,
    RecoverbullOwnOperations,
    RecoverbullAlerts,
  ],
)
final class RecoverBullDatabase extends _$RecoverBullDatabase {
  static const schema = 1;

  RecoverBullDatabase.forTesting(super.executor);

  factory RecoverBullDatabase.open(String path) =>
      RecoverBullDatabase.forTesting(
        NativeDatabase.createInBackground(
          File(path),
          setup: (database) {
            final version =
                database.select('PRAGMA user_version').single['user_version']
                    as int;
            if (version > schema) {
              throw const RecoverBullUnsupportedSchemaException();
            }
            database.execute('PRAGMA busy_timeout = 2000');
            database.execute('PRAGMA journal_mode = WAL');
            database.execute('PRAGMA synchronous = FULL');
            database.execute('PRAGMA secure_delete = ON');
          },
        ),
      );

  @override
  int get schemaVersion => schema;

  /// This unpublished feature keeps one v1 baseline. Creation is atomic so a
  /// killed first launch cannot leave partially created tables behind.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(migrator.createAll),
    onUpgrade: (_, _, _) async =>
        throw const RecoverBullUnsupportedSchemaException(),
  );

  Future<void> forceOpen() async {
    final rows = await customSelect('PRAGMA integrity_check').get();
    if (rows.length != 1 ||
        rows.single.read<String>('integrity_check') != 'ok') {
      throw const RecoverBullDatabaseIntegrityException();
    }
    await into(recoverbullState).insert(
      const RecoverbullStateCompanion(id: Value(1)),
      mode: InsertMode.insertOrIgnore,
    );
  }
}

final class RecoverBullUnsupportedSchemaException implements Exception {
  const RecoverBullUnsupportedSchemaException();
}

final class RecoverBullDatabaseIntegrityException implements Exception {
  const RecoverBullDatabaseIntegrityException();
}
