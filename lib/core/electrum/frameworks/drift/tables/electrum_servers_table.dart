import 'package:drift/drift.dart';

@DataClassName('ElectrumServerRow')
class ElectrumServers extends Table {
  TextColumn get url => text()();
  BoolColumn get isTestnet => boolean()();
  BoolColumn get isLiquid => boolean()();
  IntColumn get priority => integer()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {url};
}
