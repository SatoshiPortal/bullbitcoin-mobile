import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Adds the embedded Tor transport preference and the last route that
/// successfully bootstrapped. Existing installs start in automatic mode and
/// have no remembered route until their next successful connection.
class Schema14To15 {
  static Future<void> migrate(Migrator m, Schema15 schema15) async {
    await m.addColumn(schema15.settings, schema15.settings.torTransportMode);
    await m.addColumn(
      schema15.settings,
      schema15.settings.lastSuccessfulTorTransport,
    );
  }
}
