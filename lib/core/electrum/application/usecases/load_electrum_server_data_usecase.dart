import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/electrum_settings_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/load_electrum_server_data_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/responses/load_electrum_server_data_response.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class LoadElectrumServerDataUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;
  final EnvironmentPort _environmentPort;
  final ServerStatusPort _serverStatusPort;
  final SettingsRepository _settingsRepository;

  const LoadElectrumServerDataUsecase({
    required ElectrumServerRepository electrumServerRepository,
    required ElectrumSettingsRepository electrumSettingsRepository,
    required EnvironmentPort environmentPort,
    required ServerStatusPort serverStatusPort,
    required SettingsRepository settingsRepository,
  }) : _electrumServerRepository = electrumServerRepository,
       _electrumSettingsRepository = electrumSettingsRepository,
       _environmentPort = environmentPort,
       _serverStatusPort = serverStatusPort,
       _settingsRepository = settingsRepository;

  Future<LoadElectrumServerDataResponse> execute(
    LoadElectrumServerDataRequest request,
  ) async {
    final isLiquid = request.isLiquid;
    final environment = await _environmentPort.getEnvironment();

    // Fetch servers, settings, and app settings in parallel
    final (servers, settings, appSettings) =
        await (
          _electrumServerRepository.fetchAll(
            isTestnet: environment.isTestnet,
            isLiquid: isLiquid,
          ),
          _electrumSettingsRepository.fetchByNetwork(
            ElectrumServerNetwork.fromEnvironment(
              isTestnet: environment.isTestnet,
              isLiquid: isLiquid,
            ),
          ),
          _settingsRepository.fetch(),
        ).wait;

    if (servers.isEmpty) {
      throw Exception('No Electrum servers found');
    }

    // Check server statuses (use Tor proxy if enabled for Bitcoin/Testnet, not Liquid)
    final useTorProxy = !isLiquid && appSettings.useTorProxy;
    final serverStatusMap = <String, ElectrumServerStatus>{};
    await Future.wait(
      servers.map((server) async {
        final status = await _serverStatusPort.checkServerStatus(
          url: server.url,
          useTorProxy: useTorProxy,
          torProxyPort: appSettings.torProxyPort,
        );
        serverStatusMap[server.url] = status;
      }),
    );

    // Return the response DTO
    return LoadElectrumServerDataResponse(
      servers: servers.map((e) => ElectrumServerDto.fromDomain(e)).toList(),
      serverStatuses: serverStatusMap,
      settings: ElectrumSettingsDto.fromDomain(settings),
      useTorProxy: appSettings.useTorProxy,
      torProxyPort: appSettings.torProxyPort,
    );
  }
}
