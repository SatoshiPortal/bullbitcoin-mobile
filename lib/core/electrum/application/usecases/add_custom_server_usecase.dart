import 'package:bb_mobile/core/electrum/application/dtos/requests/add_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/application/errors/electrum_servers_exception.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class AddCustomServerUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ServerStatusPort _serverStatusPort;
  final SettingsRepository _settingsRepository;

  AddCustomServerUsecase({
    required ElectrumServerRepository electrumServerRepository,
    required ServerStatusPort serverStatusPort,
    required SettingsRepository settingsRepository,
  }) : _electrumServerRepository = electrumServerRepository,
       _serverStatusPort = serverStatusPort,
       _settingsRepository = settingsRepository;

  Future<ElectrumServerStatus> execute(AddCustomServerRequest request) async {
    final server = ElectrumServer.createCustom(
      host: request.host,
      port: request.port,
      network: request.network,
      priority: request.priority,
      enableSsl: request.enableSsl,
    );

    final existingServer = await _electrumServerRepository.fetchByUrl(
      server.url,
    );
    if (existingServer != null) {
      // If the server already exists, throw an error
      throw ElectrumServerAlreadyExistsException(server.url);
    }

    // Fetch app settings to get Tor configuration
    final appSettings = await _settingsRepository.fetch();
    final useTorProxy = !server.network.isLiquid && appSettings.useTorProxy;

    // Step 1: verify the TCP/SSL socket is reachable
    final socketStatus = await _serverStatusPort.checkSocket(
      url: server.url,
      useTorProxy: useTorProxy,
      torProxyPort: appSettings.torProxyPort,
    );
    if (socketStatus == ElectrumServerStatus.offline) {
      return ElectrumServerStatus.offline;
    }

    // Step 2: verify the server actually serves chain data by fetching a
    // known historical tx (falls back to server.version on testnets).
    final protocolStatus = await _serverStatusPort.checkElectrum(
      url: server.url,
      network: server.network,
    );
    if (protocolStatus == ElectrumServerStatus.offline) {
      return ElectrumServerStatus.offline;
    }

    // Both checks passed — persist the server
    await _electrumServerRepository.save(server);
    return ElectrumServerStatus.online;
  }
}
