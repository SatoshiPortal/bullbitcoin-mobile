import 'package:drift/drift.dart';

@DataClassName('WalletMetadataBackupStateRow')
class WalletMetadataBackupStates extends Table {
  IntColumn get id => integer()(); // single row, id == 1
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  IntColumn get dirtyRevision => integer().withDefault(const Constant(0))();
  IntColumn get lastAttemptedAt => integer().nullable()();
  IntColumn get lastSucceededAt => integer().nullable()();
  IntColumn get remoteGeneration => integer().nullable()();
  TextColumn get remoteEtag => text().nullable()();
  IntColumn get lastVerifiedSnapshotRevision => integer().nullable()();
  TextColumn get lastVerifiedContentHash => text().nullable()();
  IntColumn get lastVerifiedAt => integer().nullable()();
  IntColumn get blockedRemoteGeneration => integer().nullable()();
  TextColumn get blockedRemoteEtag => text().nullable()();
  IntColumn get blockedEnvelopeVersion => integer().nullable()();
  IntColumn get blockedObservedAt => integer().nullable()();
  TextColumn get recoveryBlockedReason => text().nullable()();
  IntColumn get recoveryBlockedRemoteGeneration => integer().nullable()();
  TextColumn get recoveryBlockedRemoteEtag => text().nullable()();
  IntColumn get recoveryBlockedSnapshotRevision => integer().nullable()();
  IntColumn get recoveryBlockedObservedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
