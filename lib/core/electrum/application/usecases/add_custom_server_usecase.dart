import 'package:bb_mobile/core/electrum/application/dtos/requests/add_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_tor_session_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
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

      // The timeout and retry policy still comes from the active settings.
      // Domain validation is relaxed below because adding a custom server
      // also persists that custom-server policy atomically.
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
      final effectiveTimeout = ElectrumConnection.resolveEffectiveTimeout(
        url: server.url,
        configuredTimeout: electrumSettings.timeout,
      );
      try {
        // Bitcoin's BDK probe already establishes the socket and validates
        // the protocol. Liquid keeps the separate socket check until its
        // protocol probe uses the same production client stack.
        if (server.network.isLiquid) {
          final socketStatus = await _serverStatusPort.checkSocket(
            url: server.url,
            timeout: effectiveTimeout,
            proxyEndpoint: route?.endpoint,
          );
          if (socketStatus == ElectrumServerStatus.offline) {
            return const Err(ElectrumServerUnreachableFailure());
          }
        }

        // Verify that the server actually serves chain data.
        final protocolStatus = await _serverStatusPort.checkElectrum(
          url: server.url,
          network: server.network,
          validateDomain: false,
          timeout: effectiveTimeout,
          retry: electrumSettings.retry,
          proxyEndpoint: route?.endpoint,
        );
        if (protocolStatus == ElectrumServerStatus.offline) {
          return const Err(ElectrumServerUnreachableFailure());
        }
      } finally {
        await route?.close();
      }

      switch (await _electrumServerRepository.save(server)) {
        case Ok():
          break;
        case Err(:final failure):
          return Err(failure);
      }

      if (electrumSettings.validateDomain) {
        electrumSettings.update(newValidateDomain: false);
        switch (await _electrumSettingsRepository.save(electrumSettings)) {
          case Ok():
            break;
          case Err(:final failure):
            final rollback = await _electrumServerRepository.delete(
              url: server.url,
            );
            if (rollback case Err(:final failure)) {
              log.severe(
                message: 'Failed to roll back custom electrum server',
                error: failure,
                trace: StackTrace.current,
              );
            }
            return Err(failure);
        }
      }

      return const Ok(ElectrumServerStatus.online);
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
