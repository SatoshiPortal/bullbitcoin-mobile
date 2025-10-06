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
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
}
