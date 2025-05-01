import 'dart:io';

import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter/foundation.dart';

class ElectrumServerRepository {
  final ElectrumServerStorageDatasource _electrumServerStorage;

  const ElectrumServerRepository({
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
  }) : _electrumServerStorage = electrumServerStorageDatasource;

  Future<void> setElectrumServer(ElectrumServer server) async {
    final model = ElectrumServerModel.fromEntity(server);
    await _electrumServerStorage.store(model);
  }

  /// Checks if a server is reachable by attempting a socket connection
  Future<ElectrumServerStatus> _checkServerConnectivity(
    String url,
    int? timeout,
  ) async {
    try {
      if (url.isEmpty) {
        return ElectrumServerStatus.unknown;
      }

      final uri = Uri.parse(url);
      if (uri.host.isEmpty || uri.port == 0) {
        return ElectrumServerStatus.offline;
      }

      final socket = await Socket.connect(
            uri.host,
            uri.port,
            timeout: Duration(seconds: timeout ?? 5),
          )
          .then((socket) {
            socket.destroy();
            return ElectrumServerStatus.online;
          })
          .catchError((error) {
            debugPrint('Socket connection error: $error');
            return ElectrumServerStatus.offline;
          });
      return socket;
    } catch (e) {
      debugPrint('Error checking server connectivity: $e');
      return ElectrumServerStatus.offline;
    }
  }

  Future<ElectrumServer?> getDefaultServerByProvider({
    required DefaultElectrumServerProvider provider,
    required Network network,
    bool checkStatus = false,
  }) async {
    // Try to get the server from storage
    final model = await _electrumServerStorage.fetchDefaultServerByProvider(
      provider,
      network: network,
    );

    if (model == null) throw '$provider is not accessible';

    // Get the URL directly from the model
    final url = model.url;
    final server = model.toEntity();

    if (checkStatus) {
      // Check connectivity
      final status = await _checkServerConnectivity(url, server.timeout);
      return server.copyWith(status: status);
    }
    return server;
  }

  Future<ElectrumServer?> getCustomServer({
    required Network network,
    bool checkStatus = false,
  }) async {
    // Get custom server if available
    final model = await _electrumServerStorage.fetchCustomServer(
      network: network,
    );

    if (model != null) {
      final server = model.toEntity();
      if (checkStatus && model.url.isNotEmpty) {
        // Check connectivity if needed
        final status = await _checkServerConnectivity(
          model.url,
          server.timeout,
        );
        return server.copyWith(status: status);
      }
      return server;
    }
    return null;
  }

  Future<List<ElectrumServer>> getElectrumServers({
    required Network network,
    required bool checkStatus,
  }) async {
    List<ElectrumServer> servers = [];

    // Get custom server if available
    final customServer = await getCustomServer(network: network);
    if (customServer != null) {
      servers.add(customServer);
    }

    // Get BullBitcoin server (priority 1)
    final bullBitcoin = await getDefaultServerByProvider(
      provider: DefaultElectrumServerProvider.bullBitcoin,
      network: network,
    );
    if (bullBitcoin != null) {
      servers.add(bullBitcoin);
    }

    // Get Blockstream server (priority 2)
    final blockstream = await getDefaultServerByProvider(
      provider: DefaultElectrumServerProvider.blockstream,
      network: network,
    );
    if (blockstream != null) {
      servers.add(blockstream);
    }

    // Check status for all servers if needed
    if (checkStatus) {
      debugPrint('Checking server status for ${servers.length} servers...');
      final List<ElectrumServer> serversWithStatus = [];

      for (final server in servers) {
        if (server.url.isNotEmpty) {
          try {
            final status = await _checkServerConnectivity(
              server.url,
              server.timeout,
            );
            debugPrint('Server: ${server.url}, Status: $status');
            serversWithStatus.add(server.copyWith(status: status));
          } catch (e) {
            debugPrint('Error checking server status: $e');
            serversWithStatus.add(
              server.copyWith(status: ElectrumServerStatus.offline),
            );
          }
        } else {
          serversWithStatus.add(server);
        }
      }

      servers = serversWithStatus;
    }

    return servers;
  }

  Future<ElectrumServer> getPrioritizedServer({
    required Network network,
    bool checkStatus = false,
  }) async {
    // Get custom server if available
    final model = await _electrumServerStorage.fetchPrioritizedServer(
      network: network,
    );

    final server = model.toEntity();
    if (checkStatus && model.url.isNotEmpty) {
      // Check connectivity if needed
      final status = await _checkServerConnectivity(model.url, server.timeout);
      return server.copyWith(status: status);
    }
    return server;
  }
}

extension FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
