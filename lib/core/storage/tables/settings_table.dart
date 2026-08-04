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
  TextColumn get torTransportMode =>
      text().withDefault(const Constant('automatic'))();
  TextColumn get lastSuccessfulTorTransport => text().nullable()();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  BoolColumn get isErrorReportingEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get exchangeTestnetBasicAuthUsername => text().nullable()();
  TextColumn get exchangeTestnetBasicAuthPassword => text().nullable()();

  // No payjoin columns here: the Payjoin policy lives in payjoin.sqlite, owned
  // by the bull_payjoin package. During development, schema 14 briefly added
  // payjoin_enabled, payjoin_min_amount_sat and payjoin_expire_after_sec here,
  // but they were removed before schema 14 shipped in v6.13.0.
}
