import 'package:bb_mobile/core/storage/database_seeds.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/core/utils/constants.dart';
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
    final fulcrumUrl = ApiServiceConstants.fulcrumElectrumUrl;
    final fulcrumUrlWithoutProtocol = fulcrumUrl.replaceAll('ssl://', '');

    // Delete any existing custom entries for the fulcrum server
    await (m.database.delete(electrumServers)..where(
          (e) =>
              electrumServers.url.equals(fulcrumUrl) |
              electrumServers.url.equals(fulcrumUrlWithoutProtocol),
        ))
        .go();

    // Get all Bitcoin mainnet servers and update their priority
    final serversToUpdate =
        await (m.database.select(electrumServers)..where(
              (e) =>
                  electrumServers.isTestnet.equals(0) &
                  electrumServers.isLiquid.equals(0),
            ))
            .get();

    for (final server in serversToUpdate) {
      final url = server.read('url') as String;
      final isTestnet = server.read('is_testnet') as bool;
      final isLiquid = server.read('is_liquid') as bool;
      final priority = server.read('priority') as int;
      final isCustom = server.read('is_custom') as bool;

      await m.database
          .into(electrumServers)
          .insertOnConflictUpdate(
            RawValuesInsertable({
              'url': Constant(url),
              'is_testnet': Constant(isTestnet),
              'is_liquid': Constant(isLiquid),
              'priority': Constant(priority + 1),
              'is_custom': Constant(isCustom),
            }),
          );
    }

    await m.database
        .into(electrumServers)
        .insert(
          RawValuesInsertable({
            'url': Constant(fulcrumUrl),
            'is_testnet': const Constant(false),
            'is_liquid': const Constant(false),
            'priority': const Constant(0),
            'is_custom': const Constant(false),
          }),
        );

    // Add mempool tables
    await m.createTable(schema11.mempoolServers);
    await m.createTable(schema11.mempoolSettings);

    // Seed default mempool data
    await DatabaseSeeds.seedDefaultMempoolServers(db);
    await DatabaseSeeds.seedDefaultMempoolSettings(db);
  }
}
