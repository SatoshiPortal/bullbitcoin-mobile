import 'package:drift/drift.dart';

@DataClassName('WalletBackupStateRow')
class WalletBackupStates extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();

  /// The latest committed backup-relevant local mutation, incremented in the
  /// same transaction as the write it records for owners in this database.
  IntColumn get localRevision => integer().withDefault(const Constant(0))();

  /// The local revision a successful store acknowledged. The backup is dirty
  /// while [localRevision] is ahead of it; no boolean mirrors that fact.
  IntColumn get uploadedRevision => integer().withDefault(const Constant(0))();
  IntColumn get lastSucceededAt => integer().nullable()();
  TextColumn get lastRecoveryStatus => text().nullable()();
  IntColumn get unsupportedVersion => integer().nullable()();

  /// The one durable recovery fence: idle, applying, or needsAttention.
  TextColumn get recoveryState => text().withDefault(const Constant('idle'))();
  TextColumn get serverUrl => text().nullable()();
  IntColumn get remoteGeneration => integer().nullable()();
  TextColumn get remoteEtag => text().nullable()();
  TextColumn get remoteCiphertextHash => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
