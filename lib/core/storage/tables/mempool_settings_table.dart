import 'package:drift/drift.dart';

@DataClassName('MempoolSettingsRow')
class MempoolSettings extends Table {
  TextColumn get network => text()();
  BoolColumn get useForFeeEstimation =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {network};
}
