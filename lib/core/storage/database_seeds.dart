import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class DatabaseSeeds {
  static Future<void> seedDefaultSettings(SqliteDatabase db) async {
    log.info('[SqliteDatabase] seeding default settings...');
    await db
        .into(db.settings)
        .insert(
          SettingsRow(
            id: 1,
            environment: Environment.mainnet.name,
            bitcoinUnit: BitcoinUnit.sats.name,
            language: Language.unitedStatesEnglish.name,
            currency: 'CAD',
            hideAmounts: false,
            isSuperuser: false,
            isDevModeEnabled: false,
            hideExchangeFeatures: false,
          ),
        );
  }

  static Future<void> seedDefaultElectrumServers(SqliteDatabase db) async {
    final serversData = [
      (ApiServiceConstants.bbElectrumUrl, false, false, 0),
      (ApiServiceConstants.bbLiquidElectrumUrlPath, false, true, 0),
      (ApiServiceConstants.publicElectrumUrl, false, false, 1),
      (ApiServiceConstants.publicLiquidElectrumUrlPath, false, true, 1),
      (ApiServiceConstants.publicElectrumTestUrl, true, false, 0),
      (ApiServiceConstants.publicliquidElectrumTestUrlPath, true, true, 0),
    ];

    for (final (url, isTestnet, isLiquid, priority) in serversData) {
      final server = ElectrumServerRow(
        url: url,
        isTestnet: isTestnet,
        isLiquid: isLiquid,
        priority: priority,
        isCustom: false,
      );

      await db.into(db.electrumServers).insertOnConflictUpdate(server);
    }
  }

  static Future<void> seedDefaultElectrumSettings(SqliteDatabase db) async {
    final networks = [
      ElectrumServerNetwork.bitcoinMainnet,
      ElectrumServerNetwork.bitcoinTestnet,
      ElectrumServerNetwork.liquidMainnet,
      ElectrumServerNetwork.liquidTestnet,
    ];

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
            enabled: false,
            balanceThresholdSats: 1000000,
            feeThresholdPercent: 3.0,
            blockTillNextExecution: false,
            alwaysBlock: false,
          ),
        );
    await db
        .into(db.autoSwap)
        .insert(
          const AutoSwapRow(
            id: 2,
            enabled: false,
            balanceThresholdSats: 1000000,
            feeThresholdPercent: 3.0,
            blockTillNextExecution: false,
            alwaysBlock: false,
          ),
        );
  }
}
