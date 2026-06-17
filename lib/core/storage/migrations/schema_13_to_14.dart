import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Migration from version 13 to 14
///
/// Additive only — adds the `frozen_utxos` table backing user freeze
/// persistence (issue #760). Existing data is untouched. Idempotent: if the
/// table already exists (e.g. a partially-applied migration) the create is
/// swallowed so re-running is safe on this self-custodial DB.
class Schema13To14 {
  static Future<void> migrate(Migrator m, Schema14 schema14) async {
    try {
      await m.createTable(schema14.frozenUtxos);
    } catch (e) {
      if (!e.toString().contains('already exists')) rethrow;
    }
  }
}
