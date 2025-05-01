import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:drift/drift.dart';

class ElectrumServerStorageDatasource {
  final SqliteDatasource _sqliteDatasource;

  const ElectrumServerStorageDatasource({
    required SqliteDatasource sqliteDatasource,
  }) : _sqliteDatasource = sqliteDatasource;

  Future<void> store(ElectrumServerModel server) async {
    final row = server.toSqlite();
    await _sqliteDatasource
        .into(_sqliteDatasource.electrumServers)
        .insertOnConflictUpdate(row);
  }

  /// Get a default server by preset type
  Future<ElectrumServerModel?> fetchDefaultServerByProvider(
    DefaultElectrumServerProvider provider, {
    required Network network,
  }) async {
    final row =
        await _sqliteDatasource.managers.electrumServers
            .filter(
              (f) =>
                  f.isLiquid(network.isLiquid) &
                  f.isTestnet(network.isTestnet) &
                  f.priority.not(0),
            )
            .getSingleOrNull();
    if (row == null) return null;
    return ElectrumServerModel.fromSqlite(row);
  }

  /// Get custom server for a specific network
  Future<ElectrumServerModel?> fetchCustomServer({
    required Network network,
  }) async {
    final row =
        await _sqliteDatasource.managers.electrumServers
            .filter(
              (f) =>
                  f.isLiquid(network.isLiquid) &
                  f.isTestnet(network.isTestnet) &
                  f.priority(0),
            )
            .getSingleOrNull();
    if (row == null) return null;
    return ElectrumServerModel.fromSqlite(row);
  }

  Future<ElectrumServerModel> fetchPrioritizedServer({
    required Network network,
  }) async {
    final rows =
        await _sqliteDatasource.managers.electrumServers
            .filter(
              (f) =>
                  f.isLiquid(network.isLiquid) & f.isTestnet(network.isTestnet),
            )
            .get();

    final servers = rows.map((e) => ElectrumServerModel.fromSqlite(e)).toList();

    // Sort servers by priority
    servers.sort((a, b) => a.priority.compareTo(b.priority));
    return servers.first;
  }
}
