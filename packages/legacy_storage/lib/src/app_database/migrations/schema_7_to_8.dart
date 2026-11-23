import 'package:drift/drift.dart';

import '../sqlite_database.steps.dart';

class Schema7To8 {
  static Future<void> migrate(Migrator m, Schema8 schema8) async {
    await m.deleteTable('wallet_addresses');
  }
}
