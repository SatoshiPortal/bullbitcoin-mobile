import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema10To11 {
  static Future<void> migrate(Migrator m, Schema11 schema11) async {
    await m.createTable(schema11.prices);
  }
}
