import 'package:electrum/electrum.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/auto_swap.drift.dart';
import 'package:electrum/storage.dart';
import 'package:preferences/recoverbull_table.drift.dart';
import 'package:bull_recoverbull/migration.dart' show RecoverBullLegacyDefaults;
import 'package:electrum/setup.dart' show ElectrumDefaultEndpoints;
import 'package:mempool/migration.dart' show MempoolLegacyDefaults;
import 'package:bull_logger/bull_logger.dart';
import 'package:mempool/storage.dart';

class DatabaseSeeds {
  static Future<void> seedDefaultElectrumServers(SqliteDatabase db) async {
    final serversData = [
      (ElectrumDefaultEndpoints.fulcrumElectrumUrl, false, false, 0),
      (ElectrumDefaultEndpoints.bbElectrumUrl, false, false, 1),
      (ElectrumDefaultEndpoints.bbLiquidElectrumUrlPath, false, true, 0),
      (ElectrumDefaultEndpoints.publicElectrumUrl, false, false, 2),
      (ElectrumDefaultEndpoints.publicLiquidElectrumUrlPath, false, true, 1),
      (ElectrumDefaultEndpoints.publicElectrumTestUrl, true, false, 0),
      (ElectrumDefaultEndpoints.publicliquidElectrumTestUrlPath, true, true, 0),
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
            url: RecoverBullLegacyDefaults.recoverbullUrl,
            isPermissionGranted: false,
          ),
        );
  }

  static Future<void> seedDefaultMempoolServers(SqliteDatabase db) =>
      MempoolSeeds.seedDefaultServers(
        db,
        bitcoinMainnet: MempoolLegacyDefaults.bbMempoolUrlPath,
        bitcoinTestnet: MempoolLegacyDefaults.testnetMempoolUrlPath,
        liquidMainnet: MempoolLegacyDefaults.bbLiquidMempoolUrlPath,
        liquidTestnet: MempoolLegacyDefaults.bbLiquidMempoolTestnetUrlPath,
      );

  static Future<void> seedDefaultMempoolSettings(SqliteDatabase db) =>
      MempoolSeeds.seedDefaultSettings(db);
}
