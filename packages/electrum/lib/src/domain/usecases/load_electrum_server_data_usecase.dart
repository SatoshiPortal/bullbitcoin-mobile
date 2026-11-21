import 'package:electrum/src/application/dtos/electrum_server_dto.dart';
import 'package:electrum/src/application/dtos/electrum_settings_dto.dart';
import 'package:electrum/src/application/dtos/requests/load_electrum_server_data_request.dart';
import 'package:electrum/src/application/dtos/responses/load_electrum_server_data_response.dart';
import 'package:electrum/src/domain/electrum_server.dart';
import 'package:electrum/src/domain/entities/electrum_settings.dart';
import 'package:electrum/src/domain/electrum_failure.dart';
import 'package:electrum/src/domain/ports/environment_port.dart';
import 'package:electrum/src/domain/ports/server_status_port.dart';
import 'package:electrum/src/domain/ports/electrum_tor_session_port.dart';
import 'package:electrum/src/domain/repositories/electrum_server_repository.dart';
import 'package:electrum/src/domain/repositories/electrum_settings_repository.dart';
import 'package:electrum/src/domain/electrum_server_network.dart';
import 'package:electrum/src/domain/value_objects/electrum_server_status.dart';
import 'package:electrum/src/domain/value_objects/electrum_connection.dart';
import 'package:electrum/src/domain/electrum_preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class LoadElectrumServerDataUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;
  final EnvironmentPort _environmentPort;
  final ServerStatusPort _serverStatusPort;
  final ElectrumTorSessionPort _torSessionPort;
  final Future<ElectrumPreferences> Function() _readPreferences;

  const LoadElectrumServerDataUsecase({
    required this._electrumServerRepository,
    required this._electrumSettingsRepository,
    required this._environmentPort,
    required this._serverStatusPort,
    required this._torSessionPort,
    required this._readPreferences,
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
        environment: environment,
        isLiquid: isLiquid,
      );

      final (serversResult, settingsResult) = await (
        _electrumServerRepository.fetchAll(network: network),
        _electrumSettingsRepository.fetchByNetwork(network),
      ).wait;

      final List<ElectrumServer> servers;
      switch (serversResult) {
        case Ok(:final value):
          servers = value;
        case Err(:final failure):
          return Err(failure);
      }
      // Not final: Dart 3.14.0 AOT crashes on a switch-assigned final captured by a closure (dart-lang/sdk#64917).
      ElectrumSettings settings;
      switch (settingsResult) {
        case Ok(:final value):
          settings = value;
        case Err(:final failure):
          return Err(failure);
      }

      if (servers.isEmpty) {
        return const Err(ElectrumLoadFailure('No Electrum servers found'));
      }

      final appSettings = await _readPreferences();
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
              validateDomain: !server.isCustom || settings.validateDomain,
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
    } on Exception {
      log.warning('Electrum server data unavailable');
      return const Err(ElectrumUnexpectedFailure());
    }
  }
}
