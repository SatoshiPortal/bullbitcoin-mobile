import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class ElectrumConnectivityAdapter implements ElectrumConnectivityPort {
  final ElectrumServerRepository _electrumServerRepository;
  final ServerStatusPort _serverStatusPort;
  final SettingsRepository _settingsRepository;

  ElectrumConnectivityAdapter({
    required ElectrumServerRepository electrumServerRepository,
    required ServerStatusPort serverStatusPort,
    required SettingsRepository settingsRepository,
  }) : _electrumServerRepository = electrumServerRepository,
       _serverStatusPort = serverStatusPort,
       _settingsRepository = settingsRepository;

  @override
  Future<bool> checkServersInUseAreOnlineForNetwork(Network network) async {
    final serverNetwork = ElectrumServerNetwork.fromEnvironment(
      isTestnet: network.isTestnet,
      isLiquid: network.isLiquid,
    );

    final (servers, _) = await (
      _electrumServerRepository.fetchAll(
        isTestnet: serverNetwork.isTestnet,
        isLiquid: serverNetwork.isLiquid,
      ),
      _settingsRepository.fetch(),
    ).wait;

    if (servers.isEmpty) return false;

    // Prefer custom servers if any are configured
    final customServers = servers.where((s) => s.isCustom).toList();
    final serversToCheck = customServers.isNotEmpty ? customServers : servers;

    // Check all servers concurrently by fetching a known historical tx —
    // proves the server actually serves chain data, not just that it speaks
    // the Electrum protocol. Online if at least one server responds correctly.
    final statuses = await Future.wait(
      serversToCheck.map(
        (server) => _serverStatusPort.checkElectrum(
          url: server.url,
          network: serverNetwork,
        ),
      ),
    );

    return statuses.any((s) => s == ElectrumServerStatus.online);
  }
}
