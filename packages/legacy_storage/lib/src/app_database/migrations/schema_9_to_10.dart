import 'package:drift/drift.dart';

import '../historical_defaults.dart';
import 'migration_guards.dart';
import '../sqlite_database.dart';
import '../sqlite_database.steps.dart';

class Schema9To10 {
  static Future<void> migrate(Migrator m, Schema10 schema10) async {
    await m.createTable(schema10.recoverbull);

    // Only set the Tor defaults when this run adds the columns: a second run
    // would turn off a Tor proxy the user has since enabled.
    final addTorColumns = !await m.hasColumn('settings', 'use_tor_proxy');

    final settings = schema10.settings;
    await m.addColumnIfMissing(settings, settings.useTorProxy);
    await m.addColumnIfMissing(settings, settings.torProxyPort);

    if (addTorColumns) {
      final db = m.database as SqliteDatabase;
      await db.managers.settings.update(
        (f) => f(
          id: const Value(1),
          useTorProxy: const Value(false),
          torProxyPort: const Value(9050),
        ),
      );
    }

    await m.database
        .into(schema10.recoverbull)
        .insert(
          RawValuesInsertable({
            'id': const Constant(1),
            'url': const Constant(HistoricalDefaults.recoverbullUrl),
            'is_permission_granted': const Constant(false),
          }),
          mode: InsertMode.insertOrIgnore,
        );
  }
}
