import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:drift/drift.dart';

class ElectrumServerStorageDatasource {
  final SqliteDatabase _sqlite;

  const ElectrumServerStorageDatasource({required SqliteDatabase sqlite})
    : _sqlite = sqlite;

  Future<void> store(ElectrumServerModel server) async {
    final row = server.toSqlite();
    await _sqlite.into(_sqlite.electrumServers).insertOnConflictUpdate(row);
  }

  /// Get a default server by preset type
  Future<ElectrumServerModel?> fetchDefaultServerByProvider(
    DefaultElectrumServerProvider provider, {
    required Network network,
  }) async {
    int? priority;
    switch (provider) {
      case DefaultElectrumServerProvider.bullBitcoin:
        priority = 1;
      case DefaultElectrumServerProvider.blockstream:
        priority = 2;
    }

    final rows =
        await _sqlite.managers.electrumServers
            .filter(
              (f) =>
                  f.isLiquid(network.isLiquid) &
                  f.isTestnet(network.isTestnet) &
                  f.priority(priority),
            )
            .get();

    if (rows.isEmpty) throw 'No servers found for $provider and $network ';

    return ElectrumServerModel.fromSqlite(rows.first);
  }

  /// Get custom server for a specific network
  Future<ElectrumServerModel?> fetchCustomServer({
    required Network network,
  }) async {
    final row =
        await _sqlite.managers.electrumServers
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
        await _sqlite.managers.electrumServers
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
