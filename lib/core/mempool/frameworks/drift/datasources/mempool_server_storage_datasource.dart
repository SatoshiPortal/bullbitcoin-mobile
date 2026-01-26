import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_server_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class MempoolServerStorageDatasource {
  final SqliteDatabase _sqlite;

  const MempoolServerStorageDatasource({required SqliteDatabase sqlite})
    : _sqlite = sqlite;

  Future<void> store(MempoolServerModel server) async {
    try {
      final row = server.toSqlite();
      await _sqlite.into(_sqlite.mempoolServers).insertOnConflictUpdate(row);

      log.fine('Successfully stored/updated mempool server: ${server.url}');
    } catch (e) {
      log.severe('Failed to store/update mempool server: $e', trace: StackTrace.current);
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
    final row = await _sqlite.managers.mempoolServers
        .filter((f) => f.isLiquid(network.isLiquid))
        .filter((f) => f.isTestnet(network.isTestnet))
        .filter((f) => f.isCustom(isCustom))
        .getSingleOrNull();

    return row == null ? null : MempoolServerModel.fromSqlite(row);
  }

  Future<bool> deleteCustomServer(MempoolServerNetwork network) async {
    try {
      final deleted =
          await _sqlite.managers.mempoolServers
              .filter((f) => f.isLiquid(network.isLiquid))
              .filter((f) => f.isTestnet(network.isTestnet))
              .filter((f) => f.isCustom(true))
              .delete();

      log.fine('Deleted $deleted custom mempool server(s) for network: $network');
      return deleted > 0;
    } catch (e) {
      log.severe('Failed to delete custom mempool server: $e', trace: StackTrace.current);
      return false;
    }
  }
}
