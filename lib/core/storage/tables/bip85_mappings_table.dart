import 'package:drift/drift.dart';

@DataClassName('Bip85MappingRow')
class Bip85Mappings extends Table {
  TextColumn get seedFingerprint => text()();
  TextColumn get masterSeedFingerprint => text()();
  TextColumn get bip85DerivationPath => text()();

  @override
  Set<Column> get primaryKey => {seedFingerprint};
}
