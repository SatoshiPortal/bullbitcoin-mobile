import 'package:bb_mobile/core/infra/database/database_seeds.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:drift/drift.dart';

class Schema0To1 {
  static Future<void> onCreate(Migrator m) async {
    await m.createAll();

    // Seed database with default values
    // !Important! If future migrations add columns that require default
    //  values as well, the seeding of that column has to be done in the
    //  migration step as well, since either the onCreate or the migration
    //  steps get executed, not both. Make sure in the migration you only
    //  seed the new columns and don't overwrite any existing data.
    await Future.wait([
      DatabaseSeeds.seedDefaultSettings(m.database as SqliteDatabase),
      DatabaseSeeds.seedDefaultElectrumServers(m.database as SqliteDatabase),
      DatabaseSeeds.seedDefaultElectrumSettings(m.database as SqliteDatabase),
      DatabaseSeeds.seedDefaultAutoSwap(m.database as SqliteDatabase),
      DatabaseSeeds.seedDefaultRecoverbull(m.database as SqliteDatabase),
    ]);
  }
}
