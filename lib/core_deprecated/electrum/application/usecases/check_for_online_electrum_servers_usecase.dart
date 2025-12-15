import 'package:bb_mobile/core_deprecated/electrum/application/dtos/requests/check_for_online_electrum_servers_request.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/repositories/electrum_server_repository.dart';

import 'package:bb_mobile/core_deprecated/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/repositories/settings_repository.dart';

class CheckForOnlineElectrumServersUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final EnvironmentPort _environmentPort;
  final ServerStatusPort _serverStatusPort;
  final SettingsRepository _settingsRepository;

  const CheckForOnlineElectrumServersUsecase({
    required ElectrumServerRepository electrumServerRepository,
    required EnvironmentPort environmentPort,
    required ServerStatusPort serverStatusPort,
    required SettingsRepository settingsRepository,
  }) : _electrumServerRepository = electrumServerRepository,
       _environmentPort = environmentPort,
       _serverStatusPort = serverStatusPort,
       _settingsRepository = settingsRepository;

  Future<bool> execute(CheckForOnlineElectrumServersRequest request) async {
    final isLiquid = request.isLiquid;
    final environment = await _environmentPort.getEnvironment();

    // Fetch servers and app settings in parallel
    final (servers, appSettings) =
        await (
          _electrumServerRepository.fetchAll(isTestnet: environment.isTestnet),
          _settingsRepository.fetch(),
        ).wait;

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

      // Check server statuses (use Tor for Bitcoin, not Liquid)
      final useTorProxy = !isLiquid && appSettings.useTorProxy;
      final filteredServersStatusses = await Future.wait(
        filteredServersToUse.map((server) async {
          final status = await _serverStatusPort.checkServerStatus(
            url: server.url,
            useTorProxy: useTorProxy,
            torProxyPort: appSettings.torProxyPort,
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

      // Check server statuses (use Tor for Bitcoin, not Liquid)
      final liquidServersStatusses = await Future.wait(
        liquidServersToUse.map((server) async {
          final status = await _serverStatusPort.checkServerStatus(
            url: server.url,
            useTorProxy: false,
            torProxyPort: appSettings.torProxyPort,
          );
          return status;
        }),
      );
      final bitcoinServersStatusses = await Future.wait(
        bitcoinServersToUse.map((server) async {
          final status = await _serverStatusPort.checkServerStatus(
            url: server.url,
            useTorProxy: appSettings.useTorProxy,
            torProxyPort: appSettings.torProxyPort,
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
