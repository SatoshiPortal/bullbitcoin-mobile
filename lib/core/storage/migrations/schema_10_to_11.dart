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
          schema11.autoSwap.triggerBalanceSats:
              schema11.autoSwap.balanceThresholdSats * const Constant(2),
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
      (f) => f(themeMode: const Value('system')),
    );

    final electrumServers = schema11.electrumServers;
    const fulcrumUrl = 'ssl://fulcrum.bullbitcoin.com:50002';
    const fulcrumUrlWithoutProtocol = 'fulcrum.bullbitcoin.com:50002';

    await m.database.customUpdate(
      'DELETE FROM electrum_servers WHERE url = ? OR url = ?',
      variables: [
        Variable<String>(fulcrumUrl),
        Variable<String>(fulcrumUrlWithoutProtocol),
      ],
      updates: {electrumServers},
    );

    await m.database.customUpdate(
      'UPDATE electrum_servers SET priority = priority + 1 WHERE is_testnet = 0 AND is_liquid = 0',
      updates: {electrumServers},
    );

    await m.database
        .into(electrumServers)
        .insert(
          RawValuesInsertable({
            'url': const Constant(fulcrumUrl),
            'is_testnet': const Constant(false),
            'is_liquid': const Constant(false),
            'priority': const Constant(0),
            'is_custom': const Constant(false),
          }),
        );
  }
}
