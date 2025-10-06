import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/logger.dart';
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

  // Fixed update method to ensure new server is stored after deletion
  Future<bool> update(ElectrumServerModel server) async {
    // Start a transaction for atomic operation
    return await _sqlite.transaction(() async {
      final networkDeleted =
          await _sqlite.managers.electrumServers
              .filter(
                (f) =>
                    f.isLiquid.equals(server.isLiquid) &
                    f.isTestnet.equals(server.isTestnet) &
                    f.priority(0),
              )
              .delete();

      log.fine(
        'Deleted $networkDeleted existing custom servers for this network',
      );

      try {
        await store(server);

        // Double-check the server was stored
        final checkServer = await fetchCustomServer(
          network: server.toEntity().network,
        );
        if (checkServer != null) {
          log.fine('Confirmed server was stored: ${checkServer.url}');
          return true;
        }
      } catch (e) {
        log.severe('Failed to store new server: $e');
        return false;
      }

      return false;
    });
  }

  /// Get a default server by provider type
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

    if (rows.isEmpty) return null;

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
    // First, try to find any active custom server
    final activeCustom =
        await _sqlite.managers.electrumServers
            .filter(
              (f) =>
                  f.isLiquid(network.isLiquid) &
                  f.isTestnet(network.isTestnet) &
                  f.isActive(true) &
                  f.priority(0),
            )
            .getSingleOrNull();
    if (activeCustom != null) {
      return ElectrumServerModel.fromSqlite(activeCustom);
    }

    // If no active servers found, get all servers by priority (fallback)
    final allServers =
        await _sqlite.managers.electrumServers
            .filter(
              (f) =>
                  f.isLiquid(network.isLiquid) & f.isTestnet(network.isTestnet),
            )
            .get();

    if (allServers.isEmpty) {
      throw 'No servers found for network $network';
    }

    // First try default Bull Bitcoin server
    final bullBitcoin = allServers.firstWhere(
      (row) => row.priority == 1,
      orElse: () => allServers.first,
    );

    return ElectrumServerModel.fromSqlite(bullBitcoin);
  }

  /// Delete a specific server by URL
  Future<bool> deleteServer(String url) async {
    try {
      final deleted =
          await _sqlite.managers.electrumServers
              .filter((f) => f.url.equals(url))
              .delete();

      log.fine('Deleted $deleted server(s) with URL: $url');
      return deleted > 0;
    } catch (e) {
      log.severe('Failed to delete server: $e');
      return false;
    }
  }
}
