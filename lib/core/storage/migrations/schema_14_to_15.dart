import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Migration from version 14 to 15.
///
/// Adds the persisted Tor transport preferences to the settings table.
class Schema14To15 {
  static Future<void> migrate(Migrator m, Schema15 schema15) async {
    await m.addColumn(schema15.settings, schema15.settings.torTransportMode);
    await m.addColumn(
      schema15.settings,
      schema15.settings.lastSuccessfulTorTransport,
    );
  }
}
