import 'package:drift/drift.dart';

@DataClassName('AutoSwapRow')
class AutoSwap extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  IntColumn get amountThresholdSats => integer()();
  IntColumn get feeThreshold => integer()();
}
