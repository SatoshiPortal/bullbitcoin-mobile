import 'package:bb_mobile/core/electrum/data/models/electrum_servers_table.dart';
import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:drift/drift.dart';

class ElectrumServerStorageDatasource {
  final SqliteDatasource _sqliteDatasource;

  const ElectrumServerStorageDatasource({
    required SqliteDatasource sqliteDatasource,
  }) : _sqliteDatasource = sqliteDatasource;

  Future<void> set(ElectrumServerModel server) async {
    await _sqliteDatasource
        .into(_sqliteDatasource.electrumServers)
        .insertOnConflictUpdate(server);
  }

  /// Get a default server by preset type
  Future<ElectrumServerModel?> getDefaultServerByProvider({
    required ElectrumServerProvider provider,
    required Network network,
  }) async {
    return await _sqliteDatasource.managers.electrumServers
        .filter((f) => f.provider(provider))
        .getSingleOrNull();
  }

  /// Get custom server for a specific network
  Future<ElectrumServerModel?> getCustomServer({
    required Network network,
  }) async {
    return await _sqliteDatasource.managers.electrumServers
        .filter(
          (f) => f.isLiquid(network.isLiquid) & f.isTestnet(network.isTestnet),
        )
        .getSingleOrNull();
  }

  Future<List<ElectrumServerModel>> getPrioritizedServer({
    required Network network,
  }) async {
    final servers =
        await _sqliteDatasource.managers.electrumServers
            .filter(
              (f) =>
                  f.isLiquid(network.isLiquid) & f.isTestnet(network.isTestnet),
            )
            .get();
    servers.sort((a, b) => a.priority.compareTo(b.priority));
    return servers;
  }
}
