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
          (t) =>
              electrumServers.url.equals(fulcrumUrl) |
              electrumServers.url.equals(fulcrumUrlWithoutProtocol),
        ))
        .go();

    // Get all Bitcoin mainnet servers to update their priority
    final btcMainnetServers =
        await (m.database.select(electrumServers)..where(
              (t) =>
                  electrumServers.isTestnet.equals(0) &
                  electrumServers.isLiquid.equals(0),
            ))
            .get();

    // Update each server's priority by incrementing it
    for (final server in btcMainnetServers) {
      final serverUrl = server.data['url'] as String;
      final serverIsTestnet = server.data['is_testnet'] as int;
      final serverIsLiquid = server.data['is_liquid'] as int;
      final serverPriority = server.data['priority'] as int;
      final serverIsCustom = server.data['is_custom'] as int;

      await (m.database.update(
        electrumServers,
      )..where((t) => electrumServers.url.equals(serverUrl))).write(
        RawValuesInsertable({
          'url': Constant<String>(serverUrl),
          'is_testnet': Constant<int>(serverIsTestnet),
          'is_liquid': Constant<int>(serverIsLiquid),
          'priority': Constant<int>(serverPriority + 1),
          'is_custom': Constant<int>(serverIsCustom),
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

    // Seed default mempool servers
    final mempoolServers = schema11.mempoolServers;
    final mempoolServersData = [
      {
        'url': ApiServiceConstants.bbMempoolUrlPath,
        'isTestnet': false,
        'isLiquid': false,
        'isCustom': false,
      },
      {
        'url': ApiServiceConstants.testnetMempoolUrlPath,
        'isTestnet': true,
        'isLiquid': false,
        'isCustom': false,
      },
      {
        'url': ApiServiceConstants.bbLiquidMempoolUrlPath,
        'isTestnet': false,
        'isLiquid': true,
        'isCustom': false,
      },
      {
        'url': ApiServiceConstants.bbLiquidMempoolTestnetUrlPath,
        'isTestnet': true,
        'isLiquid': true,
        'isCustom': false,
      },
    ];
    for (final server in mempoolServersData) {
      await db
          .into(mempoolServers)
          .insert(
            RawValuesInsertable({
              'url': Constant(server['url'] as String),
              'is_testnet': Constant(server['isTestnet'] as bool),
              'is_liquid': Constant(server['isLiquid'] as bool),
              'is_custom': Constant(server['isCustom'] as bool),
            }),
            mode: InsertMode.insertOrReplace,
          );
    }

    // Seed default mempool settings
    final mempoolSettings = schema11.mempoolSettings;
    final mempoolNetworks = [
      'bitcoinMainnet',
      'bitcoinTestnet',
      'liquidMainnet',
      'liquidTestnet',
    ];
    for (final network in mempoolNetworks) {
      await db
          .into(mempoolSettings)
          .insert(
            RawValuesInsertable({
              'network': Constant(network),
              'use_for_fee_estimation': const Constant(true),
            }),
            mode: InsertMode.insertOrReplace,
          );
    }
  }
}
