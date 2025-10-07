import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';

class CheckForOnlineElectrumServersUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final EnvironmentPort _environmentPort;
  final ServerStatusPort _serverStatusPort;

  const CheckForOnlineElectrumServersUsecase({
    required ElectrumServerRepository electrumServerRepository,
    required EnvironmentPort environmentPort,
    required ServerStatusPort serverStatusPort,
  }) : _electrumServerRepository = electrumServerRepository,
       _environmentPort = environmentPort,
       _serverStatusPort = serverStatusPort;

  Future<bool> execute({bool? isLiquid}) async {
    final environment = await _environmentPort.getEnvironment();

    // Fetch servers in parallel
    final servers = await _electrumServerRepository.fetchAll(
      isTestnet: environment.isTestnet,
    );

    if (isLiquid != null) {
      // Filter servers by network
      final filteredServers =
          servers
              .where((server) => server.network.isLiquid == isLiquid)
              .toList();

      if (filteredServers.isEmpty) {
        return false;
      }

      final customFilteredServers =
          filteredServers.where((server) => server.isCustom).toList();
      final filteredServersToUse =
          customFilteredServers.isNotEmpty
              ? customFilteredServers
              : filteredServers;

      // Check server statuses
      final filteredServersStatusses = await Future.wait(
        filteredServersToUse.map((server) async {
          final status = await _serverStatusPort.checkServerStatus(
            url: server.url,
          );
          return status;
        }),
      );

      // Determine if there is at least one online server
      final hasOnlineServer = filteredServersStatusses.any(
        (status) => status == ElectrumServerStatus.online,
      );

      return hasOnlineServer;
    } else {
      final liquidServers =
          servers.where((server) => server.network.isLiquid).toList();
      final customLiquidServers =
          liquidServers.where((server) => server.isCustom).toList();
      final liquidServersToUse =
          customLiquidServers.isNotEmpty ? customLiquidServers : liquidServers;
      final bitcoinServers =
          servers.where((server) => !server.network.isLiquid).toList();
      final customBitcoinServers =
          bitcoinServers.where((server) => server.isCustom).toList();
      final bitcoinServersToUse =
          customBitcoinServers.isNotEmpty
              ? customBitcoinServers
              : bitcoinServers;

      // Check server statuses
      final liquidServersStatusses = await Future.wait(
        liquidServersToUse.map((server) async {
          final status = await _serverStatusPort.checkServerStatus(
            url: server.url,
          );
          return status;
        }),
      );
      final bitcoinServersStatusses = await Future.wait(
        bitcoinServersToUse.map((server) async {
          final status = await _serverStatusPort.checkServerStatus(
            url: server.url,
          );
          return status;
        }),
      );

      // Determine if there is at least one online server for each network
      final hasOnlineLiquidServer = liquidServersStatusses.any(
        (status) => status == ElectrumServerStatus.online,
      );
      final hasOnlineBitcoinServer = bitcoinServersStatusses.any(
        (status) => status == ElectrumServerStatus.online,
      );

      return hasOnlineLiquidServer && hasOnlineBitcoinServer;
    }
  }
}
