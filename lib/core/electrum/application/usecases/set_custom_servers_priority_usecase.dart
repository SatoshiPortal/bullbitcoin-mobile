import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/set_custom_servers_priority_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/responses/set_custom_servers_priority_response.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';

class SetCustomServersPriorityUsecase {
  final ElectrumServerRepository _electrumServerRepository;

  const SetCustomServersPriorityUsecase({
    required ElectrumServerRepository electrumServerRepository,
  }) : _electrumServerRepository = electrumServerRepository;

  Future<SetCustomServersPriorityResponse> execute(
    SetCustomServersPriorityRequest request,
  ) async {
    // Update each server's priority based on its position in the list
    final servers =
        request.servers.indexed.map((record) {
          final server = record.$2.toDomain();
          server.updatePriority(record.$1);
          return server;
        }).toList();

    // Save the updated servers to the repository
    await _electrumServerRepository.batchSave(servers);

    // Return the response DTO
    return SetCustomServersPriorityResponse(
      servers: servers.map((e) => ElectrumServerDto.fromDomain(e)).toList(),
    );
  }
}
