import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema10To11 {
  static Future<void> migrate(Migrator m, Schema11 schema11) async {
    await m.createTable(schema11.prices);

    final settings = schema11.settings;
    await m.addColumn(settings, settings.themeMode);

    await m.alterTable(
      TableMigration(
        schema11.autoSwap,
        columnTransformer: {
          schema11.autoSwap.id: schema11.autoSwap.id,
          schema11.autoSwap.enabled: const Constant(true),
          schema11.autoSwap.balanceThresholdSats:
              schema11.autoSwap.balanceThresholdSats,
          schema11.autoSwap.feeThresholdPercent:
              schema11.autoSwap.feeThresholdPercent,
          schema11.autoSwap.blockTillNextExecution:
              schema11.autoSwap.blockTillNextExecution,
          schema11.autoSwap.alwaysBlock: schema11.autoSwap.alwaysBlock,
          schema11.autoSwap.recipientWalletId:
              schema11.autoSwap.recipientWalletId,
          schema11.autoSwap.showWarning: const Constant(true),
        },
        newColumns: [
          schema11.autoSwap.showWarning,
          schema11.autoSwap.triggerBalanceSats,
        ],
      ),
    );

    final db = m.database as SqliteDatabase;
    await db.managers.settings.update(
      (f) => f(id: const Value(1), themeMode: const Value('system')),
    );

    final autoSwapRows =
        await (m.database.selectOnly(schema11.autoSwap)..addColumns([
              schema11.autoSwap.id,
              schema11.autoSwap.balanceThresholdSats,
            ]))
            .get();
    for (final row in autoSwapRows) {
      final id = row.read(schema11.autoSwap.id);
      final balanceThresholdSats = row.read(
        schema11.autoSwap.balanceThresholdSats,
      );
      if (id != null && balanceThresholdSats != null) {
        await db.managers.autoSwap.update(
          (f) => f(
            id: Value(id),
            triggerBalanceSats: Value(balanceThresholdSats * 2),
          ),
        );
      }
    }
  }
}
