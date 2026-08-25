import 'package:bb_mobile/core/electrum/application/dtos/requests/add_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_tor_session_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class AddCustomServerUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;
  final ServerStatusPort _serverStatusPort;
  final ElectrumTorSessionPort _torSessionPort;
  final SettingsRepository _settingsRepository;

  AddCustomServerUsecase({
    required this._electrumServerRepository,
    required this._electrumSettingsRepository,
    required this._serverStatusPort,
    required this._torSessionPort,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<ElectrumServerStatus, ElectrumFailure>> execute(
    AddCustomServerRequest request,
  ) async {
    try {
      final server = ElectrumServer.createCustom(
        host: request.host,
        port: request.port,
        network: request.network,
        priority: request.priority,
        enableSsl: request.enableSsl,
      );

      final ElectrumServer? existingServer;
      switch (await _electrumServerRepository.fetchByUrl(server.url)) {
        case Ok(:final value):
          existingServer = value;
        case Err(:final failure):
          return Err(failure);
      }
      if (existingServer != null) {
        return const Err(ElectrumServerAlreadyExistsFailure());
      }

      // Probe with the user's own validateDomain setting: accepting a
      // certificate the sync would refuse saves a server that can never be
      // used, and the failure only surfaces later as a broken sync.
      final ElectrumSettings electrumSettings;
      switch (await _electrumSettingsRepository.fetchByNetwork(
        server.network,
      )) {
        case Ok(:final value):
          electrumSettings = value;
        case Err(:final failure):
          return Err(failure);
      }

      final appSettings = await _settingsRepository.fetch();

      final route = await _torSessionPort.open(
        network: server.network,
        serverUrl: server.url,
        isCustom: server.isCustom,
        externalProxyEnabled: appSettings.useTorProxy,
        externalProxyPort: appSettings.torProxyPort,
      );
      try {
        // Step 1: verify the TCP/SSL socket is reachable.
        final socketStatus = await _serverStatusPort.checkSocket(
          url: server.url,
          proxyEndpoint: route?.endpoint,
        );
        if (socketStatus == ElectrumServerStatus.offline) {
          return const Err(ElectrumServerUnreachableFailure());
        }

        // Step 2: verify the server actually serves chain data by fetching a
        // known historical tx (falls back to server.version on testnets).
        final protocolStatus = await _serverStatusPort.checkElectrum(
          url: server.url,
          network: server.network,
          validateDomain: electrumSettings.validateDomain,
          proxyEndpoint: route?.endpoint,
        );
        if (protocolStatus == ElectrumServerStatus.offline) {
          return const Err(ElectrumServerUnreachableFailure());
        }
      } finally {
        await route?.close();
      }

      // Both checks passed — persist the server.
      final saveResult = await _electrumServerRepository.save(server);
      return saveResult.map((_) => ElectrumServerStatus.online);
    } on OnionServerWithoutTorException catch (error, st) {
      log.severe(
        message: 'External Tor unavailable for custom onion server',
        error: error,
        trace: st,
      );
      return const Err(ElectrumExternalTorProxyUnavailableFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to add custom electrum server',
        error: e,
        trace: st,
      );
      return const Err(ElectrumUnexpectedFailure());
    }
  }
}
