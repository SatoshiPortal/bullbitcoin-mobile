import 'package:electrum/src/domain/electrum_server.dart';
import 'package:electrum/src/domain/entities/electrum_settings.dart';
import 'package:electrum/src/domain/electrum_failure.dart';
import 'package:electrum/src/domain/ports/electrum_tor_session_port.dart';
import 'package:electrum/src/domain/ports/server_status_port.dart';
import 'package:electrum/src/domain/repositories/electrum_server_repository.dart';
import 'package:electrum/src/domain/repositories/electrum_settings_repository.dart';
import 'package:electrum/src/domain/electrum_server_network.dart';
import 'package:electrum/src/domain/value_objects/electrum_server_status.dart';
import 'package:electrum/src/domain/value_objects/electrum_connection.dart';
import 'package:electrum/src/domain/errors/electrum_fallback_exception.dart';
import 'package:electrum/src/domain/electrum_preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class AddCustomServerUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;
  final ServerStatusPort _serverStatusPort;
  final ElectrumTorSessionPort _torSessionPort;
  final ReadElectrumPreferences _readPreferences;

  AddCustomServerUsecase({
    required this._electrumServerRepository,
    required this._electrumSettingsRepository,
    required this._serverStatusPort,
    required this._torSessionPort,
    required this._readPreferences,
  });

  @useResult
  Future<Result<ElectrumServer, ElectrumFailure>> execute(
    ElectrumServer server,
  ) async {
    try {
      final ElectrumServer? existingServer;
      switch (await _electrumServerRepository.fetchByUrl(
        server.url,
        network: server.network,
      )) {
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

      final appSettings = (await _readPreferences()).fold(
        (value) => value,
        (_) => null,
      );
      if (appSettings == null) return const Err(ElectrumUnexpectedFailure());

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

        // TODO: verify the Electrum genesis hash for the selected network.
        // This probe checks protocol availability only.
        final protocolStatus = await _serverStatusPort.checkElectrum(
          url: server.url,
          network: server.network,
          validateDomain: electrumSettings.validateDomain,
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

      // Both checks passed — persist the server.
      final saveResult = await _electrumServerRepository.save(server);
      return saveResult.map((_) => server);
    } on OnionServerWithoutTorException {
      log.warning('Electrum custom server probe unavailable category=tor');
      return const Err(ElectrumExternalTorProxyUnavailableFailure());
    } on ClearnetServerWithoutConfiguredTorException {
      log.warning('Electrum custom server probe unavailable category=tor');
      return const Err(ElectrumExternalTorProxyUnavailableFailure());
    } on Exception {
      log.warning(
        'Electrum custom server probe unavailable category=connection',
      );
      return const Err(ElectrumUnexpectedFailure());
    }
  }
}
