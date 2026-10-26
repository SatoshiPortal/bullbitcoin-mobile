import 'package:bb_mobile/core/storage/database_seeds.dart';
import 'package:bb_mobile/core/storage/migrations/migration_guards.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema5To6 {
  static Future<void> migrate(Migrator m, Schema6 schema6) async {
    // The seed upserts, so only seed a table that has no rows yet: re-seeding
    // would overwrite the user's electrum settings.
    final seedElectrumSettings = !await m.hasRows('electrum_settings');

    // Create ElectrumSettings table
    await m.createTable(schema6.electrumSettings);
    // Seed the new table with ElectrumSettings default values
    if (seedElectrumSettings) {
      await DatabaseSeeds.seedDefaultElectrumSettings(
        m.database as SqliteDatabase,
      );
    }

    // Add isCustom column to electrum_servers table with default value false
    // and remove columns that are now part of electrum_settings table
    final electrumServers = schema6.electrumServers;
    await m.addColumnIfMissing(electrumServers, electrumServers.isCustom);
    await m.dropColumnIfPresent(electrumServers, 'socks5');
    await m.dropColumnIfPresent(electrumServers, 'stop_gap');
    await m.dropColumnIfPresent(electrumServers, 'timeout');
    await m.dropColumnIfPresent(electrumServers, 'retry');
    await m.dropColumnIfPresent(electrumServers, 'validate_domain');
    await m.dropColumnIfPresent(electrumServers, 'is_active');

    await m.addColumnIfMissing(
      schema6.settings,
      schema6.settings.isDevModeEnabled,
    );
  }
}
