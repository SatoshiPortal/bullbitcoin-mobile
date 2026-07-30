import 'package:drift/drift.dart';

@DataClassName('SettingsRow')
class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get environment => text()();
  TextColumn get bitcoinUnit => text()();
  TextColumn get language => text()();
  TextColumn get currency => text()();
  BoolColumn get hideAmounts => boolean()();
  BoolColumn get isSuperuser => boolean()();
  BoolColumn get isDevModeEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get useTorProxy => boolean().withDefault(const Constant(false))();
  IntColumn get torProxyPort => integer().withDefault(const Constant(9050))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  BoolColumn get isErrorReportingEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get exchangeTestnetBasicAuthUsername => text().nullable()();
  TextColumn get exchangeTestnetBasicAuthPassword => text().nullable()();

  // Legacy migration source only. Runtime Payjoin policy lives in
  // payjoin.sqlite; these columns stay for one compatibility release so an
  // existing installation can be imported transactionally.
  BoolColumn get payjoinEnabled =>
      boolean().withDefault(const Constant(false))();

  // Legacy default matching PayjoinPolicy.defaults (10,000 sats).
  IntColumn get payjoinMinAmountSat =>
      integer().withDefault(const Constant(10000))();

  // Legacy default matching PayjoinPolicy.defaults (24 hours).
  IntColumn get payjoinExpireAfterSec =>
      integer().withDefault(const Constant(86400))();
}
