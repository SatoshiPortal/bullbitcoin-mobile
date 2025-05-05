import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class ElectrumServerStorageDatasource {
  final SqliteDatabase _sqlite;

  const ElectrumServerStorageDatasource({required SqliteDatabase sqlite})
    : _sqlite = sqlite;

  Future<void> store(ElectrumServerModel server) async {
    final row = server.toSqlite();
    await _sqlite.into(_sqlite.electrumServers).insertOnConflictUpdate(row);
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
    debugPrint('Found custom server: ${row.url}, isActive: ${row.isActive}');
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

    // If no active custom server, find active default servers and sort by priority
    final activeDefaults =
        await _sqlite.managers.electrumServers
            .filter(
              (f) =>
                  f.isLiquid(network.isLiquid) &
                  f.isTestnet(network.isTestnet) &
                  f.isActive(true) &
                  f.priority.not(0),
            )
            .get();

    if (activeDefaults.isNotEmpty) {
      final servers =
          activeDefaults.map((e) => ElectrumServerModel.fromSqlite(e)).toList();
      servers.sort((a, b) => a.priority.compareTo(b.priority));
      return servers.first;
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

    debugPrint(
      'Fallback server: ${bullBitcoin.url}, isActive: ${bullBitcoin.isActive}',
    );
    return ElectrumServerModel.fromSqlite(bullBitcoin);
  }
}
