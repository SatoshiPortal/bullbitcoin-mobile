import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:drift/drift.dart';

/// Migration from version 14 to 15.
///
/// Adds the settings columns introduced after the v14 release (schema 14 ships
/// in v6.13.0):
/// - `tor_transport_mode` / `last_successful_tor_transport` — persisted Tor
///   transport preferences.
/// - `screen_capture_protection_enabled` — gates screenshot/recording blocking
///   on sensitive screens (defaults to true so installs keep protection until
///   the user opts out).
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
    await _addColumnIfNotExists(
      () => m.addColumn(
        schema15.settings,
        schema15.settings.screenCaptureProtectionEnabled,
      ),
      'settings.screen_capture_protection_enabled column',
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
