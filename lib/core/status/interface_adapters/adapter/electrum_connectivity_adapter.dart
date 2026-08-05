import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class ElectrumConnectivityAdapter implements ElectrumConnectivityPort {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;
  final ServerStatusPort _serverStatusPort;

  ElectrumConnectivityAdapter({
    required this._electrumServerRepository,
    required this._electrumSettingsRepository,
    required this._serverStatusPort,
  });

  @override
  Future<bool> checkServersInUseAreOnlineForNetwork(Network network) async {
    final serverNetwork = ElectrumServerNetwork.fromEnvironment(
      isTestnet: network.isTestnet,
      isLiquid: network.isLiquid,
    );

    final (serversResult, settingsResult) = await (
      _electrumServerRepository.fetchAll(
        isTestnet: serverNetwork.isTestnet,
        isLiquid: serverNetwork.isLiquid,
      ),
      _electrumSettingsRepository.fetchByNetwork(serverNetwork),
    ).wait;

    final servers = serversResult.fold(
      (value) => value,
      (failure) => throw Exception(
        failure.logMessage ?? 'Failed to fetch electrum servers',
      ),
    );
    final settings = settingsResult.fold(
      (value) => value,
      (failure) => throw Exception(
        failure.logMessage ?? 'Failed to fetch electrum settings',
      ),
    );

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
          // The user's own setting, so "online" here means the sync can
          // actually reach the server too.
          validateDomain: settings.validateDomain,
        ),
      ),
    );

    return statuses.any((s) => s == ElectrumServerStatus.online);
  }
}
