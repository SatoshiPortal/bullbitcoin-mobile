import 'package:drift/drift.dart';

@DataClassName('ElectrumServerRow')
class ElectrumServers extends Table {
  TextColumn get url => text()();
  TextColumn get network => text()();
  IntColumn get priority => integer()();
  BoolColumn get isCustom => boolean()();

  @override
  Set<Column> get primaryKey => {network, url};
}
