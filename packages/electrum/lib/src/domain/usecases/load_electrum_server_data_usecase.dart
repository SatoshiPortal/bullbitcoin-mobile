import 'package:electrum/src/domain/electrum_server.dart';
import 'package:electrum/src/domain/entities/electrum_settings.dart';
import 'package:electrum/src/domain/electrum_failure.dart';
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

import '../value_objects/electrum_endpoint.dart';
import '../value_objects/electrum_server_url.dart';
import '../value_objects/electrum_server_checks.dart';
import '../errors/electrum_fallback_exception.dart';

class LoadElectrumServerDataUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;
  final ServerStatusPort _serverStatusPort;
  final ElectrumTorSessionPort _torSessionPort;
  final Future<ElectrumPreferences> Function() _readPreferences;

  const LoadElectrumServerDataUsecase({
    required this._electrumServerRepository,
    required this._electrumSettingsRepository,
    required this._serverStatusPort,
    required this._torSessionPort,
    required this._readPreferences,
  });

  @useResult
  Future<Result<ElectrumServerChecks, ElectrumFailure>> execute({
    required ElectrumServerNetwork network,
    void Function(ElectrumServerChecks response)? onUpdate,
  }) async {
    try {
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
      final endpoints = servers.map(toElectrumEndpoint).toList();
      final options = toElectrumOptions(settings);
      final serverStatusMap = {
        for (final server in servers) server.url: ElectrumServerStatus.unknown,
      };

      ElectrumServerChecks response() => ElectrumServerChecks(
        servers: endpoints,
        serverStatuses: serverStatusMap,
        settings: options,
      );

      onUpdate?.call(response());
      await Future.wait(
        servers.map((server) async {
          try {
            serverStatusMap[server.url] = await _probe(
              url: server.url,
              network: network,
              isCustom: server.isCustom,
              settings: settings,
              preferences: appSettings,
            );
          } on Exception {
            serverStatusMap[server.url] = ElectrumServerStatus.offline;
          } finally {
            onUpdate?.call(response());
          }
        }),
      );

      return Ok(response());
    } on Exception {
      log.warning('Electrum server data unavailable');
      return const Err(ElectrumUnexpectedFailure());
    }
  }

  Future<ElectrumServerStatus> _probe({
    required String url,
    required ElectrumServerNetwork network,
    required bool isCustom,
    required ElectrumSettings settings,
    required ElectrumPreferences preferences,
  }) async {
    final route = await _torSessionPort.open(
      network: network,
      serverUrl: url,
      isCustom: isCustom,
      externalProxyEnabled: preferences.useTorProxy,
      externalProxyPort: preferences.torProxyPort,
    );
    try {
      if (route == null && ElectrumServerUrl(url).isOnion) {
        throw OnionServerWithoutTorException(url);
      }
      return await _serverStatusPort.checkElectrum(
        url: url,
        network: network,
        validateDomain: !isCustom || settings.validateDomain,
        timeout: ElectrumConnection.resolveEffectiveTimeout(
          url: url,
          configuredTimeout: settings.timeout,
        ),
        retry: settings.retry,
        proxyEndpoint: route?.endpoint,
      );
    } finally {
      await route?.close();
    }
  }
}
