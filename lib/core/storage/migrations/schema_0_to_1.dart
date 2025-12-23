import 'package:bb_mobile/core/storage/database_seeds.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';

class Schema0To1 {
  static Future<void> onCreate(Migrator m) async {
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
}
