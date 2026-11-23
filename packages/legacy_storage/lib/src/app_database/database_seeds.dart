import 'package:bull_logger/bull_logger.dart';

import 'historical_defaults.dart';
import 'sqlite_database.dart';
import 'tables/auto_swap.drift.dart';
import 'tables/electrum_servers_table.drift.dart';
import 'tables/electrum_settings_table.dart';
import 'tables/electrum_settings_table.drift.dart';
import 'tables/mempool_servers_table.drift.dart';
import 'tables/mempool_settings_table.drift.dart';
import 'tables/recoverbull_table.drift.dart';

class DatabaseSeeds {
  static Future<void> seedDefaultElectrumServers(SqliteDatabase db) async {
    final serversData = [
      (HistoricalDefaults.fulcrumElectrumUrl, false, false, 0),
      (HistoricalDefaults.bbElectrumUrl, false, false, 1),
      (HistoricalDefaults.bbLiquidElectrumUrlPath, false, true, 0),
      (HistoricalDefaults.publicElectrumUrl, false, false, 2),
      (HistoricalDefaults.publicLiquidElectrumUrlPath, false, true, 1),
      (HistoricalDefaults.publicElectrumTestUrl, true, false, 0),
      (HistoricalDefaults.publicliquidElectrumTestUrlPath, true, true, 0),
    ];

    for (final (url, isTestnet, isLiquid, priority) in serversData) {
      final server = ElectrumServerRow(
        url: url,
        network: isLiquid
            ? (isTestnet ? 'liquidTestnet' : 'liquidMainnet')
            : (isTestnet ? 'bitcoinTestnet' : 'bitcoinMainnet'),
        priority: priority,
        isCustom: false,
      );

      await db.into(db.electrumServers).insertOnConflictUpdate(server);
    }
    await db
        .into(db.electrumServers)
        .insertOnConflictUpdate(
          const ElectrumServerRow(
            url: 'tcp://127.0.0.1:50000',
            network: 'bitcoinRegtest',
            priority: 0,
            isCustom: false,
          ),
        );
  }

  static Future<void> seedDefaultElectrumSettings(SqliteDatabase db) async {
    final networks = [
      ElectrumServerNetwork.bitcoinMainnet,
      ElectrumServerNetwork.bitcoinTestnet,
      ElectrumServerNetwork.liquidMainnet,
      ElectrumServerNetwork.liquidTestnet,
    ];

    networks.add(ElectrumServerNetwork.bitcoinRegtest);

    for (final network in networks) {
      final settings = ElectrumSettingsRow(
        network: network,
        validateDomain: true,
        stopGap: 20,
        timeout: 5,
        retry: 5,
      );

      await db.into(db.electrumSettings).insertOnConflictUpdate(settings);
    }
  }

  static Future<void> seedDefaultAutoSwap(SqliteDatabase db) async {
    log.info('[SqliteDatabase] seeding default auto swap settings...');
    await db
        .into(db.autoSwap)
        .insert(
          const AutoSwapRow(
            id: 1,
            enabled: true,
            balanceThresholdSats: 250000,
            triggerBalanceSats: 500000,
            feeThresholdPercent: 1.0,
            blockTillNextExecution: false,
            alwaysBlock: false,
            showWarning: true,
          ),
        );
    await db
        .into(db.autoSwap)
        .insert(
          const AutoSwapRow(
            id: 2,
            enabled: true,
            balanceThresholdSats: 250000,
            triggerBalanceSats: 500000,
            feeThresholdPercent: 1.0,
            blockTillNextExecution: false,
            alwaysBlock: false,
            showWarning: true,
          ),
        );
  }

  static Future<void> seedDefaultRecoverbull(SqliteDatabase db) async {
    log.info('[SqliteDatabase] seeding default recoverbull...');
    await db
        .into(db.recoverbull)
        .insert(
          const RecoverbullRow(
            id: 1,
            url: HistoricalDefaults.recoverbullUrl,
            isPermissionGranted: false,
          ),
        );
  }

  static Future<void> seedDefaultMempoolServers(SqliteDatabase db) async {
    const servers = [
      (HistoricalDefaults.bbMempoolUrlPath, false, false),
      (HistoricalDefaults.testnetMempoolUrlPath, true, false),
      (HistoricalDefaults.bbLiquidMempoolUrlPath, false, true),
      (HistoricalDefaults.bbLiquidMempoolTestnetUrlPath, true, true),
    ];
    for (final (url, isTestnet, isLiquid) in servers) {
      await db
          .into(db.mempoolServers)
          .insertOnConflictUpdate(
            MempoolServerRow(
              url: url,
              isTestnet: isTestnet,
              isLiquid: isLiquid,
              isCustom: false,
              enableSsl: true,
            ),
          );
    }
  }

  static Future<void> seedDefaultMempoolSettings(SqliteDatabase db) async {
    const networks = [
      'bitcoinMainnet',
      'bitcoinTestnet',
      'liquidMainnet',
      'liquidTestnet',
    ];
    for (final network in networks) {
      await db
          .into(db.mempoolSettings)
          .insertOnConflictUpdate(
            MempoolSettingsRow(network: network, useForFeeEstimation: true),
          );
    }
  }
}
