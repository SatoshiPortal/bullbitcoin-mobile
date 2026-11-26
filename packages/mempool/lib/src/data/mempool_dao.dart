import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';
import 'package:mempool/src/domain/value_objects/mempool_server_network.dart';

import 'mempool_dao.drift.dart';
import 'models/mempool_server_model.dart';
import 'tables/mempool_servers_table.dart';
import 'tables/mempool_settings_table.dart';

@DriftAccessor(tables: [MempoolServers, MempoolSettings])
class MempoolDao extends DatabaseAccessor<GeneratedDatabase>
    with $MempoolDaoMixin {
  MempoolDao(super.attachedDatabase);

  Future<void> store(MempoolServerModel server) async {
    try {
      final row = server.toSqlite();
      await transaction(() async {
        await managers.mempoolServers
            .filter((f) => f.isLiquid(server.isLiquid))
            .filter((f) => f.isTestnet(server.isTestnet))
            .filter((f) => f.isCustom(true))
            .delete();
        await into(mempoolServers).insert(row);
      });

      log.fine('Successfully stored/updated mempool server: ${server.url}');
    } catch (e) {
      log.severe(
        message: 'Failed to store/update mempool server',
        error: e,
        trace: StackTrace.current,
      );
      rethrow;
    }
  }

  Future<MempoolServerModel?> fetchCustomServerByNetwork(
    MempoolServerNetwork network,
  ) async {
    return _fetchServerByNetwork(network, isCustom: true);
  }

  Future<MempoolServerModel?> fetchDefaultServerByNetwork(
    MempoolServerNetwork network,
  ) async {
    return _fetchServerByNetwork(network, isCustom: false);
  }

  Future<MempoolServerModel?> _fetchServerByNetwork(
    MempoolServerNetwork network, {
    required bool isCustom,
  }) async {
    final row = await managers.mempoolServers
        .filter((f) => f.isLiquid(network.isLiquid))
        .filter((f) => f.isTestnet(network.isTestnet))
        .filter((f) => f.isCustom(isCustom))
        .getSingleOrNull();

    return row == null ? null : MempoolServerModel.fromSqlite(row);
  }

  Future<bool> deleteCustomServer(MempoolServerNetwork network) async {
    try {
      final deleted = await managers.mempoolServers
          .filter((f) => f.isLiquid(network.isLiquid))
          .filter((f) => f.isTestnet(network.isTestnet))
          .filter((f) => f.isCustom(true))
          .delete();

      log.fine(
        'Deleted $deleted custom mempool server(s) for network: $network',
      );
      return deleted > 0;
    } catch (e) {
      log.severe(
        message: 'Failed to delete custom mempool server',
        error: e,
        trace: StackTrace.current,
      );
      return false;
    }
  }
}
