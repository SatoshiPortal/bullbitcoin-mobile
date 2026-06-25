import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/core/utils/logger.dart';
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
      // Idempotency guard: only swallow "table already exists" (a re-run over a
      // partially-applied v14). Match on the SQLite duplicate-table message;
      // log the swallowed error so a wording change in a future driver version
      // surfaces instead of silently turning into a hard failure.
      if (!e.toString().contains('already exists')) rethrow;
      log.warning(
        'Schema13To14: frozen_utxos already exists — skipping create',
        error: e,
      );
    }
  }
}
