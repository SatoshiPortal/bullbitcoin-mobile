import 'package:bb_mobile/core/infra/database/database_seeds.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema9To10 {
  static Future<void> migrate(Migrator m, Schema10 schema10) async {
    await m.createTable(schema10.recoverbull);

    final settings = schema10.settings;
    await m.addColumn(settings, settings.useTorProxy);
    await m.addColumn(settings, settings.torProxyPort);

    final db = m.database as SqliteDatabase;
    await db.managers.settings.update(
      (f) => f(
        id: const Value(1),
        useTorProxy: const Value(false),
        torProxyPort: const Value(9050),
      ),
    );
    await DatabaseSeeds.seedDefaultRecoverbull(db);
  }
}
