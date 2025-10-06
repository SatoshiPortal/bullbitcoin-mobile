import 'package:drift/drift.dart';

@DataClassName('ElectrumServerRow')
class ElectrumServers extends Table {
  TextColumn get url => text()();
  TextColumn get socks5 => text().nullable()();
  IntColumn get stopGap => integer()();
  IntColumn get timeout => integer()();
  IntColumn get retry => integer()();
  BoolColumn get validateDomain => boolean()();
  BoolColumn get isTestnet => boolean()();
  BoolColumn get isLiquid => boolean()();
  BoolColumn get isActive => boolean()();
  IntColumn get priority => integer()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {url};
}
