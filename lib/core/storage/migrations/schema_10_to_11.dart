import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema10To11 {
  static Future<void> migrate(Migrator m, Schema11 schema11) async {
    final settings = schema11.settings;
    await m.addColumn(settings, settings.themeMode);

    final db = m.database as SqliteDatabase;
    await db.managers.settings.update(
      (f) => f(
        id: const Value(1),
        themeMode: const Value('system'),
      ),
    );
  }
}
