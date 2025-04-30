import 'package:drift/drift.dart';

// It can be easy to invalidate your database by renaming your enum values.
enum ElectrumServerProvider { bull, blockstream, custom }

@DataClassName('ElectrumServerModel')
class ElectrumServers extends Table {
  TextColumn get url => text()();
  TextColumn get provider => textEnum<ElectrumServerProvider>()();
  TextColumn get socks5 => text().nullable()();
  IntColumn get stopGap => integer()();
  IntColumn get timeout => integer()();
  IntColumn get retry => integer()();
  BoolColumn get validateDomain => boolean()();
  BoolColumn get isTestnet => boolean()();
  BoolColumn get isLiquid => boolean()();
  BoolColumn get isActive => boolean()();
  IntColumn get priority => integer()();

  @override
  Set<Column> get primaryKey => {url};
}
