import 'package:drift/drift.dart';

import 'mempool_dao.dart';
import 'tables/mempool_servers_table.drift.dart';
import 'tables/mempool_settings_table.drift.dart';

class MempoolSeeds {
  static Future<void> seedDefaultServers(
    GeneratedDatabase database, {
    required String bitcoinMainnet,
    required String bitcoinTestnet,
    required String liquidMainnet,
    required String liquidTestnet,
  }) async {
    final dao = MempoolDao(database);
    final servers = [
      (bitcoinMainnet, false, false),
      (bitcoinTestnet, true, false),
      (liquidMainnet, false, true),
      (liquidTestnet, true, true),
    ];
    for (final (url, isTestnet, isLiquid) in servers) {
      await dao
          .into(dao.mempoolServers)
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

  static Future<void> seedDefaultSettings(GeneratedDatabase database) async {
    final dao = MempoolDao(database);
    const networks = [
      'bitcoinMainnet',
      'bitcoinTestnet',
      'liquidMainnet',
      'liquidTestnet',
    ];
    for (final network in networks) {
      await dao
          .into(dao.mempoolSettings)
          .insertOnConflictUpdate(
            MempoolSettingsRow(network: network, useForFeeEstimation: true),
          );
    }
  }
}
