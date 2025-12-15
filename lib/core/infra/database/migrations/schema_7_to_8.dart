import 'package:bb_mobile/core/infra/database/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema7To8 {
  static Future<void> migrate(Migrator m, Schema8 schema8) async {
    await m.deleteTable('wallet_addresses');
  }
}
