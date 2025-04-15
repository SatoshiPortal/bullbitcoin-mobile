import 'dart:io';

import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';

class ElectrumServerRepositoryImpl implements ElectrumServerRepository {
  final ElectrumServerStorageDatasource _electrumServerStorage;

  const ElectrumServerRepositoryImpl({
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
  }) : _electrumServerStorage = electrumServerStorageDatasource;

  @override
  Future<void> setElectrumServer(ElectrumServer server) async {
    final model = ElectrumServerModel.fromEntity(server);
    await _electrumServerStorage.set(model);
  }

  /// Checks if a server is reachable by attempting a socket connection
  Future<ElectrumServerStatus> _checkServerConnectivity(
    String url,
    int timeout,
  ) async {
    try {
      final uri = Uri.parse(url);
      final socket = await Socket.connect(
        uri.host,
        uri.port,
        timeout: Duration(seconds: timeout),
      );
      await socket.close();
      return ElectrumServerStatus.online;
    } catch (e) {
      return ElectrumServerStatus.offline;
    }
  }

  @override
  Future<ElectrumServer> getElectrumServer({
    required ElectrumServerProvider provider,
    required Network network,
    bool checkStatus = false,
  }) async {
    ElectrumServerModel? model = await _electrumServerStorage.getByProvider(
      provider,
      network: network,
    );

    if (model == null) {
      switch (provider) {
        case ElectrumServerProvider.bullBitcoin:
          model = ElectrumServerModel.bullBitcoin(
            isTestnet: network.isTestnet,
            isLiquid: network.isLiquid,
          );
        case ElectrumServerProvider.blockstream:
          model = ElectrumServerModel.blockstream(
            isTestnet: network.isTestnet,
            isLiquid: network.isLiquid,
          );
        case ElectrumServerProvider.custom:
          throw Exception('Custom electrum server not found');
      }
    }

    ElectrumServer server = model.toEntity();

    if (checkStatus) {
      final status = await _checkServerConnectivity(server.url, server.timeout);
      server = server.copyWith(status: status);
    }

    return server;
  }

  @override
  Future<List<ElectrumServer>> getElectrumServers({
    required Network network,
    bool checkStatus = false,
  }) async {
    // Get custom server if available
    final custom = await _electrumServerStorage.getByProvider(
      ElectrumServerProvider.custom,
      network: network,
    );

    // Get or create blockstream server
    final blockstream = await _electrumServerStorage.getByProvider(
          ElectrumServerProvider.blockstream,
          network: network,
        ) ??
        ElectrumServerModel.blockstream(
          isTestnet: network.isTestnet,
          isLiquid: network.isLiquid,
        );

    // Get or create Bull Bitcoin server
    final bullBitcoin = await _electrumServerStorage.getByProvider(
          ElectrumServerProvider.bullBitcoin,
          network: network,
        ) ??
        ElectrumServerModel.bullBitcoin(
          isTestnet: network.isTestnet,
          isLiquid: network.isLiquid,
        );

    // Create entity objects and check status if needed
    final blockstreamEntity = blockstream.toEntity();
    final bullBitcoinEntity = bullBitcoin.toEntity();

    List<ElectrumServer> servers = [
      if (custom != null) custom.toEntity(),
      blockstreamEntity,
      bullBitcoinEntity,
    ];

    // Check status for all servers if needed
    if (checkStatus) {
      final List<ElectrumServer> serversWithStatus = [];

      for (final server in servers) {
        final status =
            await _checkServerConnectivity(server.url, server.timeout);
        serversWithStatus.add(server.copyWith(status: status));
      }

      servers = serversWithStatus;
    }

    return servers;
  }
}
