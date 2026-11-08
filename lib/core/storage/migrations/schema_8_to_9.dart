import 'package:bb_mobile/core/storage/migrations/migration_guards.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema8To9 {
  static Future<void> migrate(Migrator m, Schema9 schema9) async {
    // Add serverNetworkFees column to swaps table
    final swaps = schema9.swaps;
    await m.addColumnIfMissing(swaps, swaps.serverNetworkFees);
  }
}
