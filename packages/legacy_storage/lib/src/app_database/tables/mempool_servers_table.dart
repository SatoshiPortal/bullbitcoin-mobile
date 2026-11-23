import 'package:drift/drift.dart';

@DataClassName('MempoolServerRow')
class MempoolServers extends Table {
  TextColumn get url => text()();
  BoolColumn get isTestnet => boolean()();
  BoolColumn get isLiquid => boolean()();
  BoolColumn get isCustom => boolean()();
  BoolColumn get enableSsl => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {url, isTestnet, isLiquid};
}
