import 'package:bb_mobile/core/storage/migrations/migration_guards.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema15To16 {
  static Future<void> migrate(Migrator m, Schema16 schema16) async {
    await m.addColumnIfMissing(
      schema16.mempoolServers,
      schema16.mempoolServers.validateDomain,
    );
  }
}
