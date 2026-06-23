import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/set_custom_servers_priority_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/responses/set_custom_servers_priority_response.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class SetCustomServersPriorityUsecase {
  final ElectrumServerRepository _electrumServerRepository;

  const SetCustomServersPriorityUsecase({
    required this._electrumServerRepository,
  });

  @useResult
  Future<Result<SetCustomServersPriorityResponse, ElectrumFailure>> execute(
    SetCustomServersPriorityRequest request,
  ) async {
    // Top-level try/catch keeps this use-case from ever throwing, so the bloc's
    // switch always completes and the loading flag is always reset.
    try {
      // Update each server's priority based on its position in the list
      final servers = request.servers.indexed.map((record) {
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

      // Save the updated servers, then map to the response DTO on success.
      final result = await _electrumServerRepository.batchSave(servers);
      return result.map(
        (_) => SetCustomServersPriorityResponse(
          servers: servers.map((e) => ElectrumServerDto.fromDomain(e)).toList(),
        ),
      );
    } catch (e, st) {
      log.severe(
        message: 'Failed to set custom servers priority',
        error: e,
        trace: st,
      );
      return Err(ElectrumUnexpectedFailure(e.toString()));
    }
  }
}
