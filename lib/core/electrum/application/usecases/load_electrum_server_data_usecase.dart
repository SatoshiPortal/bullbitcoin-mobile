import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/electrum_settings_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/responses/load_electrum_server_data_response.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';

class LoadElectrumServerDataUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;
  final EnvironmentPort _environmentPort;
  final ServerStatusPort _serverStatusPort;

  const LoadElectrumServerDataUsecase({
    required ElectrumServerRepository electrumServerRepository,
    required ElectrumSettingsRepository electrumSettingsRepository,
    required EnvironmentPort environmentPort,
    required ServerStatusPort serverStatusPort,
  }) : _electrumServerRepository = electrumServerRepository,
       _electrumSettingsRepository = electrumSettingsRepository,
       _environmentPort = environmentPort,
       _serverStatusPort = serverStatusPort;

  Future<LoadElectrumServerDataResponse> execute() async {
    final environment = await _environmentPort.getEnvironment();

    // Fetch servers and settings in parallel
    final (servers, settings) =
        await (
          _electrumServerRepository.fetchAll(isTestnet: environment.isTestnet),
          _electrumSettingsRepository.fetchByEnvironment(environment),
        ).wait;

    // Check that there is at least one server and setting for each network
    final bitcoinSettings = settings.where((s) => !s.network.isLiquid);
    final liquidSettings = settings.where((s) => s.network.isLiquid);
    if (bitcoinSettings.isEmpty) {
      throw Exception('No Bitcoin advanced settings found');
    }
    if (liquidSettings.isEmpty) {
      throw Exception('No Liquid advanced settings found');
    }
    if (servers.where((s) => !s.network.isLiquid).isEmpty) {
      throw Exception('No Bitcoin Electrum servers found');
    }
    if (servers.where((s) => s.network.isLiquid).isEmpty) {
      throw Exception('No Liquid Electrum servers found');
    }

    // Check server statuses
    final serverStatusMap = <String, ElectrumServerStatus>{};
    await Future.wait(
      servers.map((server) async {
        final status = await _serverStatusPort.checkServerStatus(
          url: server.url,
        );
        serverStatusMap[server.url] = status;
      }),
    );

    // Return the response DTO
    return LoadElectrumServerDataResponse(
      servers: servers.map((e) => ElectrumServerDto.fromDomain(e)).toList(),
      serverStatuses: serverStatusMap,
      bitcoinSettings: ElectrumSettingsDto.fromDomain(bitcoinSettings.first),
      liquidSettings: ElectrumSettingsDto.fromDomain(liquidSettings.first),
    );
  }
}
