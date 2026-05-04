import 'package:drift/drift.dart';

@DataClassName('PosAuthorizedTerminalRow')
class PosAuthorizedTerminals extends Table {
  TextColumn get merchantPubkey => text()();
  TextColumn get posId => text()();
  TextColumn get terminalPubkey => text()();
  TextColumn get terminalId => text()();
  TextColumn get ctDescriptorRef => text()();
  TextColumn get saleBucketSecretRef => text()();
  IntColumn get saleBucketGeneration => integer()();
  IntColumn get effectiveFromEpochDay => integer()();
  IntColumn get terminalIndex => integer()();
  IntColumn get authorizedAt => integer()();
  IntColumn get revokedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {merchantPubkey, posId, terminalPubkey};
}
