import 'package:bb_mobile/core_deprecated/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:drift/drift.dart';

@DataClassName('ElectrumSettingsRow')
class ElectrumSettings extends Table {
  TextColumn get network => textEnum<ElectrumServerNetwork>()();
  BoolColumn get validateDomain => boolean()();
  IntColumn get stopGap => integer()();
  IntColumn get timeout => integer()();
  IntColumn get retry => integer()();
  TextColumn get socks5 => text().nullable()();

  @override
  Set<Column> get primaryKey => {network};
}
