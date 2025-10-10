import 'package:bb_mobile/core/storage/database_seeds.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema5To6 {
  static Future<void> migrate(Migrator m, Schema6 schema6) async {
    // Create ElectrumSettings table
    await m.createTable(schema6.electrumSettings);
    // Seed the new table with ElectrumSettings default values
    await DatabaseSeeds.seedDefaultElectrumSettings(
      m.database as SqliteDatabase,
    );

    // Add isCustom column to electrum_servers table with default value false
    // and remove columns that are now part of electrum_settings table
    final electrumServers = schema6.electrumServers;
    await m.addColumn(electrumServers, electrumServers.isCustom);
    await m.dropColumn(electrumServers, 'socks5');
    await m.dropColumn(electrumServers, 'stop_gap');
    await m.dropColumn(electrumServers, 'timeout');
    await m.dropColumn(electrumServers, 'retry');
    await m.dropColumn(electrumServers, 'validate_domain');
    await m.dropColumn(electrumServers, 'is_active');

    await m.addColumn(schema6.settings, schema6.settings.isDevModeEnabled);
  }
}
