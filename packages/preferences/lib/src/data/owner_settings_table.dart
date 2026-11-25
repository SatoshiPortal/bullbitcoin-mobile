import 'package:drift/drift.dart';

@DataClassName('OwnerSettingsRow')
class OwnerSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get environment => text()();
  TextColumn get bitcoinUnit => text()();
  BoolColumn get startAmountsInFiat =>
      boolean().withDefault(const Constant(false))();
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
  BoolColumn get screenCaptureProtectionEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showPaymentAnimations =>
      boolean().withDefault(const Constant(true))();

  @override
  String get tableName => 'settings';
}
