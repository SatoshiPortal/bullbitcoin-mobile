import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/electrum_settings_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/responses/get_electrum_servers_to_broadcast_response.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class GetElectrumServersToBroadcastUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;

  const GetElectrumServersToBroadcastUsecase({
    required ElectrumServerRepository electrumServerRepository,
    required ElectrumSettingsRepository electrumSettingsRepository,
  }) : _electrumServerRepository = electrumServerRepository,
       _electrumSettingsRepository = electrumSettingsRepository;

  Future<GetElectrumServersToBroadcastResponse> execute({
    required ElectrumServerNetwork network,
  }) async {
    // Fetch servers and settings in parallel
    final (servers, settings) =
        await (
          _electrumServerRepository.fetchAll(
            isTestnet: network.isTestnet,
            isLiquid: network.isLiquid,
          ),
          _electrumSettingsRepository.fetchByNetwork(network),
        ).wait;

    // If custom servers exist, we should use them only
    final customServers = servers.where((s) => s.isCustom).toList();
    final serversToUse = customServers.isNotEmpty ? customServers : servers;

    // Return the response DTO
    return GetElectrumServersToBroadcastResponse(
      servers:
          serversToUse.map((e) => ElectrumServerDto.fromDomain(e)).toList(),
      settings: ElectrumSettingsDto.fromDomain(settings),
    );
  }
}
