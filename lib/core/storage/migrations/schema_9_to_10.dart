import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema9To10 {
  static Future<void> migrate(Migrator m, Schema10 schema10) async {
    await m.createTable(schema10.recoverbull);
  }
}
