import 'package:bb_mobile/core_deprecated/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/dtos/requests/set_custom_servers_priority_request.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/dtos/responses/set_custom_servers_priority_response.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/repositories/electrum_server_repository.dart';

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
          final (index, dto) = record;
          final server = ElectrumServer.existing(
            url: dto.url,
            network: dto.network,
            isCustom: dto.isCustom,
            priority: dto.priority,
          );
          server.updatePriority(index);
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
