import 'package:bb_mobile/core/storage/database_seeds.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema1To2 {
  static Future<void> migrate(Migrator m, Schema2 schema2) async {
    // Create AutoSwap table (without recipientWalletId column) and seed it
    await m.createTable(schema2.autoSwap);
    await DatabaseSeeds.seedDefaultAutoSwap(m.database as SqliteDatabase);
  }
}
