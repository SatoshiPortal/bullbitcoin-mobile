import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/electrum_settings_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/load_electrum_server_data_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/responses/load_electrum_server_data_response.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class LoadElectrumServerDataUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;
  final EnvironmentPort _environmentPort;
  final ServerStatusPort _serverStatusPort;
  final SettingsRepository _settingsRepository;

  const LoadElectrumServerDataUsecase({
    required this._electrumServerRepository,
    required this._electrumSettingsRepository,
    required this._environmentPort,
    required this._serverStatusPort,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<LoadElectrumServerDataResponse, ElectrumFailure>> execute(
    LoadElectrumServerDataRequest request,
  ) async {
    try {
      final isLiquid = request.isLiquid;
      final environment = await _environmentPort.getEnvironment();

      // Fetch servers, settings, and app settings in parallel
      final (serversResult, settingsResult, appSettings) = await (
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

      final List<ElectrumServer> servers;
      switch (serversResult) {
        case Ok(:final value):
          servers = value;
        case Err(:final failure):
          return Err(failure);
      }
      final ElectrumSettings settings;
      switch (settingsResult) {
        case Ok(:final value):
          settings = value;
        case Err(:final failure):
          return Err(failure);
      }

      if (servers.isEmpty) {
        return const Err(ElectrumLoadFailure('No Electrum servers found'));
      }

      // Check server statuses (use Tor proxy if enabled for Bitcoin/Testnet, not Liquid)
      final useTorProxy = !isLiquid && appSettings.useTorProxy;
      final serverStatusMap = <String, ElectrumServerStatus>{};
      await Future.wait(
        servers.map((server) async {
          final status = await _serverStatusPort.checkSocket(
            url: server.url,
            useTorProxy: useTorProxy,
            torProxyPort: appSettings.torProxyPort,
          );
          serverStatusMap[server.url] = status;
        }),
      );

      // Return the response DTO
      return Ok(
        LoadElectrumServerDataResponse(
          servers: servers.map((e) => ElectrumServerDto.fromDomain(e)).toList(),
          serverStatuses: serverStatusMap,
          settings: ElectrumSettingsDto.fromDomain(settings),
          useTorProxy: appSettings.useTorProxy,
          torProxyPort: appSettings.torProxyPort,
        ),
      );
    } catch (e, st) {
      log.severe(
        message: 'Failed to load electrum server data',
        error: e,
        trace: st,
      );
      return Err(ElectrumUnexpectedFailure(e.toString()));
    }
  }
}
