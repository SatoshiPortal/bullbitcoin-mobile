import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:drift/drift.dart';

/// Migration from version 14 to 15
///
/// Adds the brute-force telemetry baseline tables:
/// - `recoverbull_telemetry_server`: one row per key-server URL — the
///   `/attempts` polling state (ETag, last successful check, the server's
///   `attempts_collection_started_at` for wipe detection, consecutive
///   failures and the unavailability-warning dedup timestamp).
/// - `recoverbull_telemetry_backup`: one row per monitored backup — the
///   user's own operation counters (`expected_total_attempts`) with window
///   tracking, plus the warning dedup and acknowledgement timestamps. The
///   raw backup id never enters this table, only `sha256(raw backup id)`.
///
/// Both tables are created empty: existing installs simply start with no
/// telemetry baseline, which the check orchestration treats as "nothing
/// monitored yet".
///
/// Also adds the `is_recoverbull_telemetry_enabled` column to the settings
/// table (default false): whether brute-force telemetry checks (`/attempts`
/// polling and suspicious-activity warnings) are enabled. Disabled by
/// default — the feature rolls out only after the server contract and the
/// pinned client are confirmed in production. The DB default backfills
/// existing rows automatically; no manual backfill is needed.
class Schema14To15 {
  static Future<void> migrate(Migrator m, Schema15 schema15) async {
    try {
      await m.createTable(schema15.recoverbullTelemetryServer);
    } catch (e) {
      // Idempotency guard: only swallow "table already exists" (a re-run over
      // a partially-applied migration) — log it so a driver wording change
      // surfaces instead of silently becoming a hard failure.
      if (!e.toString().contains('already exists')) rethrow;
      log.warning(
        'Schema14To15: recoverbull_telemetry_server already exists — skipping create',
        error: e,
      );
    }
    try {
      await m.createTable(schema15.recoverbullTelemetryBackup);
    } catch (e) {
      if (!e.toString().contains('already exists')) rethrow;
      log.warning(
        'Schema14To15: recoverbull_telemetry_backup already exists — skipping create',
        error: e,
      );
    }
    try {
      await m.addColumn(
        schema15.settings,
        schema15.settings.isRecoverbullTelemetryEnabled,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
      log.warning(
        'Schema14To15: is_recoverbull_telemetry_enabled already exists — skipping',
        error: e,
      );
    }
  }
}
