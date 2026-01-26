import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/features/secrets/frameworks/drift/populate_secret_usages_migration.dart';
import 'package:drift/drift.dart';

/// Migration from version 12 to 13
class Schema12To13 {
  static Future<void> migrate(Migrator m, Schema13 schema13) async {
    PopulateSecretUsagesMigration.migrate(m, schema13);
  }
}
