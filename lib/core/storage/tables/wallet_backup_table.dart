import 'package:drift/drift.dart';

@DataClassName('WalletBackupStateRow')
class WalletBackupStates extends Table {
  TextColumn get identity => text()();
  IntColumn get generation => integer().nullable()();
  TextColumn get etag => text().nullable()();
  TextColumn get ciphertextHash => text().nullable()();
  TextColumn get confirmedContentHash => text().nullable()();
  DateTimeColumn get lastSuccessAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {identity};
}

@DataClassName('WalletBackupControlRow')
class WalletBackupControls extends Table {
  IntColumn get id => integer()();
  BoolColumn get enabled => boolean().nullable()();
  IntColumn get recoveryScope => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
