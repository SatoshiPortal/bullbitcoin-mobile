import 'dart:io';

import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class ElectrumServerRepository {
  final ElectrumServerStorageDatasource _electrumServerStorage;

  const ElectrumServerRepository({
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
  }) : _electrumServerStorage = electrumServerStorageDatasource;

  Future<void> storeElectrumServer({required ElectrumServer server}) async {
    final model = ElectrumServerModel.fromEntity(server);
    await _electrumServerStorage.store(model);
  }

  Future<void> updateElectrumServer({required ElectrumServer server}) async {
    final model = ElectrumServerModel.fromEntity(server);
    await _electrumServerStorage.update(model);
  }

  /// Checks if a server is reachable by attempting a socket connection
  Future<ElectrumServerStatus> checkServerConnectivity({
    required String url,
    int? timeout,
  }) async {
    try {
      if (url.isEmpty) {
        return ElectrumServerStatus.unknown;
      }
      // TODO: Remove this once lwk accepts ssl:// prefix
      // TODO: Eventually we should properly handle ssl prefix
      // If not specified, assume ssl
      // If specified, use it (tcp or ssl)
      if (!(url.startsWith('ssl://') || url.startsWith('tcp://'))) {
        url = 'ssl://$url';
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
            log.severe('Socket connection error: $error');
            return ElectrumServerStatus.offline;
          });
      return socket;
    } catch (e) {
      log.severe('Error checking server connectivity: $e');
      return ElectrumServerStatus.offline;
    }
  }

  Future<ElectrumServer?> getDefaultServerByProvider({
    required DefaultElectrumServerProvider provider,
    required Network network,
  }) async {
    // Try to get the server from storage
    final model = await _electrumServerStorage.fetchDefaultServerByProvider(
      provider,
      network: network,
    );

    if (model == null) return null;

    final server = model.toEntity();

    return server;
  }

  Future<List<ElectrumServer>> getAllDefaultServers({
    required Network network,
  }) async {
    final List<ElectrumServer> servers = [];
    for (final provider in [
      DefaultElectrumServerProvider.blockstream,
      DefaultElectrumServerProvider.bullBitcoin,
    ]) {
      // Try to get the server from storage
      final model = await _electrumServerStorage.fetchDefaultServerByProvider(
        provider,
        network: network,
      );

      if (model != null) {
        servers.add(model.toEntity());
      }
    }

    return servers;
  }

  Future<ElectrumServer?> getCustomServer({required Network network}) async {
    // Get custom server if available
    final model = await _electrumServerStorage.fetchCustomServer(
      network: network,
    );

    if (model != null) {
      final server = model.toEntity();
      return server;
    }
    return null;
  }

  Future<List<ElectrumServer>> getElectrumServers({
    required Network network,
  }) async {
    final List<ElectrumServer> servers = [];

    // Get custom server if available
    final customServer = await getCustomServer(network: network);
    if (customServer != null) {
      servers.add(customServer);
    }

    final defaultServers = await getAllDefaultServers(network: network);
    servers.addAll(defaultServers);
    return servers;
  }

  Future<ElectrumServer> getPrioritizedServer({
    required Network network,
  }) async {
    // Get custom server if available
    final model = await _electrumServerStorage.fetchPrioritizedServer(
      network: network,
    );

    final server = model.toEntity();
    return server;
  }
}
