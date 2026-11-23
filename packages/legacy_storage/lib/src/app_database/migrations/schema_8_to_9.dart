import 'package:drift/drift.dart';

import 'migration_guards.dart';
import '../sqlite_database.steps.dart';

class Schema8To9 {
  static Future<void> migrate(Migrator m, Schema9 schema9) async {
    // Add serverNetworkFees column to swaps table
    final swaps = schema9.swaps;
    await m.addColumnIfMissing(swaps, swaps.serverNetworkFees);
  }
}
