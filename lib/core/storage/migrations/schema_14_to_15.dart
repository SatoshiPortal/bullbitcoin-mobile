import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:drift/drift.dart';

/// Migration from version 14 to 15.
///
/// Adds the persisted Tor transport preferences to the settings table
/// (`tor_transport_mode`, `last_successful_tor_transport`). Schema 14 shipped in
/// v6.13.0 without these columns, so they belong in this new version rather than
/// being retrofitted into the released v14.
///
/// The adds are guarded: an early, unreleased develop build briefly added the
/// Tor columns in the 13→14 step, so a dev device may already have them. The
/// guard makes the migration idempotent instead of throwing `duplicate column`.
class Schema14To15 {
  static Future<void> migrate(Migrator m, Schema15 schema15) async {
    await _addColumnIfNotExists(
      () => m.addColumn(schema15.settings, schema15.settings.torTransportMode),
      'settings.tor_transport_mode column',
    );
    await _addColumnIfNotExists(
      () => m.addColumn(
        schema15.settings,
        schema15.settings.lastSuccessfulTorTransport,
      ),
      'settings.last_successful_tor_transport column',
    );
  }
}

Future<void> _addColumnIfNotExists(
  Future<void> Function() addColumn,
  String description,
) async {
  try {
    await addColumn();
  } catch (e) {
    // Idempotency guard: only swallow "duplicate column" (a re-run over a
    // partially-applied migration) — log it so a driver wording change surfaces
    // instead of silently becoming a hard failure.
    if (!e.toString().contains('duplicate column')) rethrow;
    log.warning(
      'Schema14To15: $description already exists — skipping add',
      error: e,
    );
  }
}
