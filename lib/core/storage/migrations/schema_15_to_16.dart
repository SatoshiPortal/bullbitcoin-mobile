import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Migration from version 15 to 16.
///
/// Drops `prices`, the price history cache: the price history now lives in
/// the pricer's own database (`packages/bull_pricer`). The rows were only a
/// cache of the price service and are fetched again on the next opening of
/// the chart. `DROP TABLE IF EXISTS` makes a second run a no-op.
class Schema15To16 {
  static Future<void> migrate(Migrator m, Schema16 schema16) async {
    await m.deleteTable('prices');
  }
}
