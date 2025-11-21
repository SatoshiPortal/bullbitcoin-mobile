import 'package:bb_mobile/core/electrum/application/dtos/requests/add_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/application/errors/electrum_servers_exception.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';

class AddCustomServerUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;
  final ServerStatusPort _serverStatusPort;

  AddCustomServerUsecase({
    required ElectrumServerRepository electrumServerRepository,
    required ElectrumSettingsRepository electrumSettingsRepository,
    required ServerStatusPort serverStatusPort,
  }) : _electrumServerRepository = electrumServerRepository,
       _electrumSettingsRepository = electrumSettingsRepository,
       _serverStatusPort = serverStatusPort;

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

    // Fetch settings for this network to get Tor configuration
    final settings = await _electrumSettingsRepository.fetchByNetwork(
      server.network,
    );

    // Save the server and check its status concurrently
    // Use Tor proxy if enabled for Bitcoin/Testnet (not Liquid)
    final useTorProxy = !server.network.isLiquid && settings.useTorProxy;
    final (_, status) =
        await (
          _electrumServerRepository.save(server),
          _serverStatusPort.checkServerStatus(
            url: server.url,
            useTorProxy: useTorProxy,
            torProxyPort: settings.torProxyPort,
          ),
        ).wait;

    // Return the status of the newly added server so it can be known if it's online or not
    return status;
  }
}
