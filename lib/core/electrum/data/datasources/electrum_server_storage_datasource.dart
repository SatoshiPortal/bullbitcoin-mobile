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

  Future<bool> update(ElectrumServerModel server) async {
    try {
      await store(server);
      log.fine('Successfully stored/updated server: ${server.url}');
      return true;
    } catch (e) {
      log.severe('Failed to store/update server: $e');
      return false;
    }
  }

  /// Get the next available priority for a custom server
  Future<int> getNextCustomServerPriority({required Network network}) async {
    final existingCustomServers = await fetchCustomServers(network: network);

    if (existingCustomServers.isEmpty) {
      return 1;
    }

    final priorities = existingCustomServers.map((s) => s.priority).toList();
    priorities.sort();
    return priorities.last + 1;
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
                  f.priority(priority) &
                  f.isCustom(false),
            )
            .get();

    if (rows.isEmpty) return null;

    return ElectrumServerModel.fromSqlite(rows.first);
  }

  /// Get custom servers for a specific network
  Future<List<ElectrumServerModel>> fetchCustomServers({
    required Network network,
  }) async {
    final rows =
        await _sqlite.managers.electrumServers
            .filter(
              (f) =>
                  f.isLiquid(network.isLiquid) &
                  f.isTestnet(network.isTestnet) &
                  f.isCustom(true),
            )
            .get();

    final servers =
        rows.map((row) => ElectrumServerModel.fromSqlite(row)).toList();
    servers.sort((a, b) => a.priority.compareTo(b.priority));
    return servers;
  }

  Future<ElectrumServerModel> fetchPrioritizedServer({
    required Network network,
  }) async {
    // First check if any custom servers exist for this network
    final customServers =
        await _sqlite.managers.electrumServers
            .filter(
              (f) =>
                  f.isLiquid(network.isLiquid) &
                  f.isTestnet(network.isTestnet) &
                  f.isCustom(true),
            )
            .get();

    // If custom servers exist, use ONLY custom servers for connection
    if (customServers.isNotEmpty) {
      // Sort custom servers by priority (1, 2, 3, ...)
      customServers.sort((a, b) => a.priority.compareTo(b.priority));

      // Return the first active custom server, or first custom server if none are active
      final activeCustom = customServers.where((s) => s.isActive).toList();
      if (activeCustom.isNotEmpty) {
        activeCustom.sort((a, b) => a.priority.compareTo(b.priority));
        return ElectrumServerModel.fromSqlite(activeCustom.first);
      }
      // If no custom servers are active, return the highest priority custom server
      return ElectrumServerModel.fromSqlite(customServers.first);
    }

    // If no custom servers exist, use default servers for connection
    final defaultServers =
        await _sqlite.managers.electrumServers
            .filter(
              (f) =>
                  f.isLiquid(network.isLiquid) &
                  f.isTestnet(network.isTestnet) &
                  f.isCustom(false), // Default servers have isCustom = false
            )
            .get();

    if (defaultServers.isEmpty) {
      throw 'No servers found for network $network';
    }

    // Sort default servers by priority (1, 2, 3, ...)
    defaultServers.sort((a, b) => a.priority.compareTo(b.priority));

    // Return the first active default server, or first default server if none are active
    final activeDefault = defaultServers.where((s) => s.isActive).toList();
    if (activeDefault.isNotEmpty) {
      activeDefault.sort((a, b) => a.priority.compareTo(b.priority));
      return ElectrumServerModel.fromSqlite(activeDefault.first);
    }

    // If no default servers are active, return the highest priority default server
    return ElectrumServerModel.fromSqlite(defaultServers.first);
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
