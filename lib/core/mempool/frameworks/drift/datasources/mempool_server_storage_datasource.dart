import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_server_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/backup_revision_recorder.dart';
import 'package:bull_logger/bull_logger.dart';

class MempoolServerStorageDatasource {
  final SqliteDatabase _sqlite;

  const MempoolServerStorageDatasource({required this._sqlite});

  Future<void> store(MempoolServerModel server) async {
    try {
      final row = server.toSqlite();
      await _sqlite.transaction(() async {
        final previous = await _fetchServerByNetwork(
          MempoolServerNetwork.fromEnvironment(
            isTestnet: server.isTestnet,
            isLiquid: server.isLiquid,
          ),
          isCustom: true,
        );
        await _sqlite.managers.mempoolServers
            .filter((f) => f.isLiquid(server.isLiquid))
            .filter((f) => f.isTestnet(server.isTestnet))
            .filter((f) => f.isCustom(true))
            .delete();
        await _sqlite.into(_sqlite.mempoolServers).insert(row);
        if (previous != (server.isCustom ? server : null)) {
          await DriftBackupRevisionRecorder(_sqlite).recordCommittedMutation();
        }
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
    try {
      return _fetchServerByNetwork(network, isCustom: true);
    } catch (_) {
      return null;
    }
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
      final deleted = await _sqlite.transaction(() async {
        final count = await _sqlite.managers.mempoolServers
            .filter((f) => f.isLiquid(network.isLiquid))
            .filter((f) => f.isTestnet(network.isTestnet))
            .filter((f) => f.isCustom(true))
            .delete();
        if (count > 0) {
          await DriftBackupRevisionRecorder(_sqlite).recordCommittedMutation();
        }
        return count;
      });

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
