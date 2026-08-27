import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
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
    await m.addColumn(schema15.settings, schema15.settings.torTransportMode);
    await m.addColumn(
      schema15.settings,
      schema15.settings.lastSuccessfulTorTransport,
    );
    await m.addColumn(
      schema15.settings,
      schema15.settings.screenCaptureProtectionEnabled,
    );
  }
}
