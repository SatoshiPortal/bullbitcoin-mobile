import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema12To13 {
  static Future<void> migrate(Migrator m, Schema13 schema13) async {
    await m.createTable(schema13.posProfiles);
    await m.createTable(schema13.posAuthorizedTerminals);
    await m.createTable(schema13.posObservedEvents);

    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS pos_observed_events_pos_kind_created_at '
      'ON pos_observed_events '
      '(merchant_pubkey, pos_id, kind, created_at DESC)',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS pos_observed_events_kind_created_at '
      'ON pos_observed_events (kind, created_at)',
    );
  }
}
