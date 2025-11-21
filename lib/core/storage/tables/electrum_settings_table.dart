import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:drift/drift.dart';

@DataClassName('ElectrumSettingsRow')
class ElectrumSettings extends Table {
  TextColumn get network => textEnum<ElectrumServerNetwork>()();
  BoolColumn get validateDomain => boolean()();
  IntColumn get stopGap => integer()();
  IntColumn get timeout => integer()();
  IntColumn get retry => integer()();
  TextColumn get socks5 => text().nullable()();
  BoolColumn get useTorProxy => boolean().withDefault(const Constant(false))();
  IntColumn get torProxyPort => integer().withDefault(const Constant(9050))();

  @override
  Set<Column> get primaryKey => {network};
}
