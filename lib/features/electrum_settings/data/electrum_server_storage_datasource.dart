import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:bb_mobile/features/electrum_settings/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';

class ElectrumServerStorageDatasource {
  final SqliteDatabase _sqlite;

  const ElectrumServerStorageDatasource({required this._sqlite});

  Future<void> store(ElectrumServerModel server) async {
    await _sqlite
        .into(_sqlite.electrumServers)
        .insertOnConflictUpdate(server.toSqlite());
    log.fine('Electrum server stored network=${server.network}');
  }

  Future<void> storeBatch(List<ElectrumServerModel> servers) async {
    await _sqlite.batch((batch) {
      for (final server in servers) {
        batch.insert(
          _sqlite.electrumServers,
          server.toSqlite(),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    log.fine('Electrum server priorities stored count=${servers.length}');
  }

  Future<ElectrumServerModel?> fetchByUrl(
    String url, {
    required ElectrumServerNetwork network,
  }) async {
    final row = await _sqlite.managers.electrumServers
        .filter(
          (f) => f.url.equals(url) & f.network.equals(network.storageName),
        )
        .getSingleOrNull();
    return row == null ? null : ElectrumServerModel.fromSqlite(row);
  }

  Future<List<ElectrumServerModel>> fetchAllServers({
    ElectrumServerNetwork? network,
    bool? isCustom,
  }) async {
    var query = _sqlite.managers.electrumServers.filter(
      (f) => const Constant(true),
    );
    if (network != null) {
      query = query.filter((f) => f.network.equals(network.storageName));
    }
    if (isCustom != null) query = query.filter((f) => f.isCustom(isCustom));
    final rows = await query.get();
    return rows.map(ElectrumServerModel.fromSqlite).toList();
  }

  Future<List<ElectrumServerModel>> fetchDefaultServersByNetwork(
    ElectrumServerNetwork network,
  ) => fetchAllServers(network: network, isCustom: false);

  Future<List<ElectrumServerModel>> fetchCustomServersByNetwork(
    ElectrumServerNetwork network,
  ) => fetchAllServers(network: network, isCustom: true);

  Future<bool> deleteServer(
    String url, {
    required ElectrumServerNetwork network,
  }) async {
    final deleted = await _sqlite.managers.electrumServers
        .filter(
          (f) => f.url.equals(url) & f.network.equals(network.storageName),
        )
        .delete();
    log.fine('Electrum server deleted network=$network count=$deleted');
    return deleted > 0;
  }
}
