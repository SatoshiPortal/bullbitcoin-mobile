import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/electrum_settings_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/load_electrum_server_data_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/responses/load_electrum_server_data_response.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_tor_session_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class LoadElectrumServerDataUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;
  final EnvironmentPort _environmentPort;
  final ServerStatusPort _serverStatusPort;
  final ElectrumTorSessionPort _torSessionPort;
  final SettingsRepository _settingsRepository;

  const LoadElectrumServerDataUsecase({
    required this._electrumServerRepository,
    required this._electrumSettingsRepository,
    required this._environmentPort,
    required this._serverStatusPort,
    required this._torSessionPort,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<LoadElectrumServerDataResponse, ElectrumFailure>> execute(
    LoadElectrumServerDataRequest request, {
    void Function(LoadElectrumServerDataResponse response)? onUpdate,
  }) async {
    try {
      final isLiquid = request.isLiquid;
      final environment = await _environmentPort.getEnvironment();
      final network = ElectrumServerNetwork.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: isLiquid,
      );

      final (serversResult, settingsResult) = await (
        _electrumServerRepository.fetchAll(
          isTestnet: environment.isTestnet,
          isLiquid: isLiquid,
        ),
        _electrumSettingsRepository.fetchByNetwork(network),
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

      final appSettings = await _settingsRepository.fetch();
      final serverDtos = servers
          .map((server) => ElectrumServerDto.fromDomain(server))
          .toList();
      final settingsDto = ElectrumSettingsDto.fromDomain(settings);
      final serverStatusMap = {
        for (final server in servers) server.url: ElectrumServerStatus.unknown,
      };

      LoadElectrumServerDataResponse response() =>
          LoadElectrumServerDataResponse(
            servers: serverDtos,
            serverStatuses: Map.unmodifiable(serverStatusMap),
            settings: settingsDto,
          );

      onUpdate?.call(response());
      await Future.wait(
        servers.map((server) async {
          final effectiveTimeout = ElectrumConnection.resolveEffectiveTimeout(
            url: server.url,
            configuredTimeout: settings.timeout,
          );
          ElectrumTorRoute? route;
          try {
            route = await _torSessionPort.open(
              network: network,
              serverUrl: server.url,
              isCustom: server.isCustom,
              externalProxyEnabled: appSettings.useTorProxy,
              externalProxyPort: appSettings.torProxyPort,
            );
            serverStatusMap[server.url] = await _serverStatusPort.checkElectrum(
              url: server.url,
              network: network,
              validateDomain: settings.validateDomain,
              timeout: effectiveTimeout,
              retry: settings.retry,
              proxyEndpoint: route?.endpoint,
            );
          } on Exception {
            serverStatusMap[server.url] = ElectrumServerStatus.offline;
          } finally {
            onUpdate?.call(response());
            await route?.close();
          }
        }),
      );

      return Ok(response());
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
