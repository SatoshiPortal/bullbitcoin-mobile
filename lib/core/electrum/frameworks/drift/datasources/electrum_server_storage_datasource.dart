import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/backup_revision_recorder.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';

class ElectrumServerStorageDatasource {
  final SqliteDatabase _sqlite;

  const ElectrumServerStorageDatasource({required this._sqlite});

  Future<void> store(ElectrumServerModel server) async {
    try {
      final row = server.toSqlite();
      await _sqlite.transaction(() async {
        final previous = await fetchByUrl(server.url);
        await _sqlite.into(_sqlite.electrumServers).insertOnConflictUpdate(row);
        final before = previous?.isCustom == true ? previous!.toSqlite() : null;
        final after = server.isCustom ? row : null;
        if (before != after) {
          await DriftBackupRevisionRecorder(_sqlite).recordCommittedMutation();
        }
      });

      log.fine('Successfully stored/updated server: ${server.url}');
    } catch (e) {
      log.severe(
        message: 'Failed to store/update server',
        error: e,
        trace: StackTrace.current,
      );
      rethrow;
    }
  }

  Future<void> storeBatch(List<ElectrumServerModel> servers) async {
    try {
      await _sqlite.transaction(() async {
        for (final server in servers) {
          await store(server);
        }
      });

      log.fine('Successfully stored/updated ${servers.length} server(s)');
    } catch (e) {
      log.severe(
        message: 'Failed to store/update multiple servers',
        error: e,
        trace: StackTrace.current,
      );
      rethrow;
    }
  }

  /// Fetch a server by its URL
  Future<ElectrumServerModel?> fetchByUrl(String url) async {
    final row = await _sqlite.managers.electrumServers
        .filter((f) => f.url.equals(url))
        .getSingleOrNull();

    return row == null ? null : ElectrumServerModel.fromSqlite(row);
  }

  Future<List<ElectrumServerModel>> fetchAllServers({
    bool? isTestnet,
    bool? isLiquid,
    bool? isCustom,
  }) async {
    var query = _sqlite.managers.electrumServers.filter(
      // No filtering by default
      (f) => const Constant(true),
    );

    if (isLiquid != null) {
      query = query.filter((f) => f.isLiquid(isLiquid));
    }
    if (isTestnet != null) {
      query = query.filter((f) => f.isTestnet(isTestnet));
    }
    if (isCustom != null) {
      query = query.filter((f) => f.isCustom(isCustom));
    }

    final rows = await query.get();
    final servers = rows
        .map((row) => ElectrumServerModel.fromSqlite(row))
        .toList();

    return servers;
  }

  /// Get a default server by provider type
  Future<List<ElectrumServerModel>> fetchDefaultServersByNetwork(
    ElectrumServerNetwork network,
  ) async {
    final rows = await _sqlite.managers.electrumServers
        .filter(
          (f) =>
              f.isLiquid(network.isLiquid) &
              f.isTestnet(network.isTestnet) &
              f.isCustom(false),
        )
        .get();

    final servers = rows
        .map((row) => ElectrumServerModel.fromSqlite(row))
        .toList();

    return servers;
  }

  /// Get custom servers for a specific network
  Future<List<ElectrumServerModel>> fetchCustomServersByNetwork(
    ElectrumServerNetwork network,
  ) async {
    final rows = await _sqlite.managers.electrumServers
        .filter(
          (f) =>
              f.isLiquid(network.isLiquid) &
              f.isTestnet(network.isTestnet) &
              f.isCustom(true),
        )
        .get();

    final servers = rows
        .map((row) => ElectrumServerModel.fromSqlite(row))
        .toList();

    return servers;
  }

  /// Delete a specific server by URL
  Future<bool> deleteServer(String url) async {
    try {
      final deleted = await _sqlite.transaction(() async {
        final previous = await fetchByUrl(url);
        final count = await _sqlite.managers.electrumServers
            .filter((f) => f.url.equals(url))
            .delete();
        if (count > 0 && previous?.isCustom == true) {
          await DriftBackupRevisionRecorder(_sqlite).recordCommittedMutation();
        }
        return count;
      });

      log.fine('Deleted $deleted server(s) with URL: $url');
      return deleted > 0;
    } catch (e) {
      log.severe(
        message: 'Failed to delete server',
        error: e,
        trace: StackTrace.current,
      );
      return false;
    }
  }
}
