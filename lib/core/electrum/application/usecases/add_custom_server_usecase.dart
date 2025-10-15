import 'package:bb_mobile/core/electrum/application/dtos/requests/add_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';

class AddCustomServerUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ServerStatusPort _serverStatusPort;

  AddCustomServerUsecase({
    required ElectrumServerRepository electrumServerRepository,
    required ServerStatusPort serverStatusPort,
  }) : _electrumServerRepository = electrumServerRepository,
       _serverStatusPort = serverStatusPort;

  Future<ElectrumServerStatus> execute(AddCustomServerRequest request) async {
    final server = ElectrumServer.createCustom(
      url: request.url,
      network: request.network,
      priority: request.priority,
    );

    // Save the server and check its status concurrently
    final (_, status) =
        await (
          _electrumServerRepository.save(server),
          _serverStatusPort.checkServerStatus(url: server.url),
        ).wait;

    // Return the status of the newly added server so it can be known if it's online or not
    return status;
  }
}
