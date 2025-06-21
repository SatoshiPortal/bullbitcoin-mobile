import 'package:drift/drift.dart';

@DataClassName('AutoSwapRow')
class AutoSwap extends Table {
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  IntColumn get amountThreshold => integer()();
  IntColumn get feeThreshold => integer()();
}
