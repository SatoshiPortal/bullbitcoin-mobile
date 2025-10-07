import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/electrum_settings_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/responses/get_electrum_servers_and_setting_by_network_response.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class GetElectrumServersAndSettingsByNetworkUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;

  const GetElectrumServersAndSettingsByNetworkUsecase({
    required ElectrumServerRepository electrumServerRepository,
    required ElectrumSettingsRepository electrumSettingsRepository,
  }) : _electrumServerRepository = electrumServerRepository,
       _electrumSettingsRepository = electrumSettingsRepository;

  Future<GetElectrumServersAndSettingsByNetworkResponse> execute(
    ElectrumServerNetwork network,
  ) async {
    // Fetch servers and settings in parallel
    final (servers, settings) =
        await (
          _electrumServerRepository.fetchAll(
            isTestnet: network.isTestnet,
            isLiquid: network.isLiquid,
          ),
          _electrumSettingsRepository.fetchByNetwork(network),
        ).wait;

    // Return the response DTO
    return GetElectrumServersAndSettingsByNetworkResponse(
      servers: servers.map((e) => ElectrumServerDto.fromDomain(e)).toList(),
      settings: ElectrumSettingsDto.fromDomain(settings),
    );
  }
}
