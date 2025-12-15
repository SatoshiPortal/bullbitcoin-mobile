import 'package:bb_mobile/core_deprecated/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/dtos/electrum_settings_dto.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/dtos/requests/get_electrum_servers_to_use_request.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/dtos/responses/get_electrum_servers_to_use_response.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/repositories/settings_repository.dart';

class GetElectrumServersToUseUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;
  final SettingsRepository _settingsRepository;

  const GetElectrumServersToUseUsecase({
    required ElectrumServerRepository electrumServerRepository,
    required ElectrumSettingsRepository electrumSettingsRepository,
    required SettingsRepository settingsRepository,
  }) : _electrumServerRepository = electrumServerRepository,
       _electrumSettingsRepository = electrumSettingsRepository,
       _settingsRepository = settingsRepository;

  Future<GetElectrumServersToUseResponse> execute(
    GetElectrumServersToUseRequest request,
  ) async {
    final network = request.network;
    // Fetch servers, settings, and app settings in parallel
    final (servers, settings, appSettings) =
        await (
          _electrumServerRepository.fetchAll(
            isTestnet: network.isTestnet,
            isLiquid: network.isLiquid,
          ),
          _electrumSettingsRepository.fetchByNetwork(network),
          _settingsRepository.fetch(),
        ).wait;

    // If custom servers exist, we should use them only
    final customServers = servers.where((s) => s.isCustom).toList();
    final serversToUse = customServers.isNotEmpty ? customServers : servers;

    // Sort servers by priority (lower number means higher priority)
    serversToUse.sort((a, b) => a.priority.compareTo(b.priority));

    // Return the response DTO
    return GetElectrumServersToUseResponse(
      servers:
          serversToUse.map((e) => ElectrumServerDto.fromDomain(e)).toList(),
      settings: ElectrumSettingsDto.fromDomain(settings),
      useTorProxy: appSettings.useTorProxy,
      torProxyPort: appSettings.torProxyPort,
    );
  }
}
