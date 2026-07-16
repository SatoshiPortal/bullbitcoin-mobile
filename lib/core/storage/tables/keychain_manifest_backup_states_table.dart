import 'package:drift/drift.dart';

@DataClassName('KeychainManifestBackupStateRow')
class KeychainManifestBackupStates extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  IntColumn get dirtyRevision => integer().withDefault(const Constant(0))();
  IntColumn get lastAttemptedAt => integer().nullable()();
  IntColumn get lastSucceededAt => integer().nullable()();
  IntColumn get remoteGeneration => integer().withDefault(const Constant(0))();
  TextColumn get remoteEtag => text().nullable()();
  TextColumn get contentHash => text().nullable()();
  IntColumn get unsupportedVersion => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
