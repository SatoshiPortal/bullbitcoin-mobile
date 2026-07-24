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

  /// Global default sync backend choice for a newly created Bitcoin
  /// wallet: when `true`, a fresh default Bitcoin wallet is created with
  /// [BitcoinSyncBackend.compactBlockFilters] instead of
  /// [BitcoinSyncBackend.electrum] (see `CreateDefaultWalletsUsecase`).
  /// Set by the wizard's privacy step; never touches an already-existing
  /// wallet. Existing installs upgrading from schema 14 backfill to
  /// `false` (schema 14 -> 15), preserving today's Electrum-only default.
  BoolColumn get useCompactBlockFiltersByDefault =>
      boolean().withDefault(const Constant(false))();
}
