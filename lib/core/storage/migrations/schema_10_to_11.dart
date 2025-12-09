import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema10To11 {
  static Future<void> migrate(Migrator m, Schema11 schema11) async {
    await m.createTable(schema11.prices);

    final settings = schema11.settings;
    await m.addColumn(settings, settings.themeMode);

    final autoSwap = schema11.autoSwap;
    await m.addColumn(autoSwap, autoSwap.showWarning);

    final db = m.database as SqliteDatabase;
    await db.managers.settings.update(
      (f) => f(id: const Value(1), themeMode: const Value('system')),
    );

    final autoSwapRows = await db.select(db.autoSwap).get();
    for (final row in autoSwapRows) {
      await db
          .update(db.autoSwap)
          .replace(row.copyWith(enabled: true, showWarning: true));
    }
  }
}
