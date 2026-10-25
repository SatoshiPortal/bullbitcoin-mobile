import 'package:bb_mobile/core/storage/database_seeds.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';

class Schema0To1 {
  /// The tables [onCreate] fills with defaults.
  static const _seededTables = {
    'settings',
    'electrum_servers',
    'electrum_settings',
    'auto_swap',
    'recoverbull',
    'mempool_servers',
    'mempool_settings',
  };

  static Future<void> onCreate(Migrator m) async {
    await _dropUnfinishedFirstLaunch(m);
    await m.createAll();

    // Seed database with default values
    // !Important! If future migrations add columns that require default
    // values as well, the seeding of that column has to be done in the
    // migration step itself using inline insertions.
    //
    // DO NOT use DatabaseSeeds functions in migrations since they reference
    // the CURRENT schema, not the historical schema at that migration version.
    // This will cause failures when columns don't exist yet.
    //
    // Instead, use RawValuesInsertable for inline data insertion:
    // - See schema_1_to_2.dart for seeding new table rows
    // - See schema_9_to_10.dart for seeding with schema-versioned tables
    // - See schema_10_to_11.dart for TableMigration with columnTransformer
    //
    // Make sure to only seed NEW columns/rows and don't overwrite existing data.
    await Future.wait([
      DatabaseSeeds.seedDefaultSettings(m.database as SqliteDatabase),
      DatabaseSeeds.seedDefaultElectrumServers(m.database as SqliteDatabase),
      DatabaseSeeds.seedDefaultElectrumSettings(m.database as SqliteDatabase),
      DatabaseSeeds.seedDefaultAutoSwap(m.database as SqliteDatabase),
      DatabaseSeeds.seedDefaultRecoverbull(m.database as SqliteDatabase),
      DatabaseSeeds.seedDefaultMempoolServers(m.database as SqliteDatabase),
      DatabaseSeeds.seedDefaultMempoolSettings(m.database as SqliteDatabase),
    ]);
  }

  /// drift runs onCreate while user_version is 0 and records the version
  /// only once it returns, so tables here are what a killed first launch left
  /// behind, possibly from an older release's schema. createAll and the seeds
  /// cannot run over them, and nothing writes user data before the first
  /// launch completes, so they are dropped and created again. A row in any
  /// table onCreate does not seed means the file holds user data: refuse
  /// instead of touching it.
  static Future<void> _dropUnfinishedFirstLaunch(Migrator m) async {
    final tables = await m.database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .map((row) => row.read<String>('name'))
        .get();
    if (tables.isEmpty) return;

    for (final table in tables) {
      if (_seededTables.contains(table)) continue;
      final rows = await m.database
          .customSelect('SELECT 1 FROM "$table" LIMIT 1')
          .get();
      if (rows.isNotEmpty) {
        throw StateError(
          'Schema0To1: $table holds rows at user_version 0, not rebuilding',
        );
      }
    }

    log.warning(
      'Schema0To1: rebuilding ${tables.length} tables left by an unfinished '
      'first launch',
    );
    for (final table in tables) {
      await m.deleteTable(table);
    }
  }
}
