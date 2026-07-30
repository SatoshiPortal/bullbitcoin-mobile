import 'package:bb_mobile/core/electrum/domain/electrum_fallback_runner.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_tor_session_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

/// Concrete [ElectrumServersPort]. Owns the only place in the app where the
/// active server list is resolved, merged with Electrum + Orbot settings, and
/// iterated — there is no other path consumers can take to reach an Electrum
/// server, which is what enforces the R1/R2/R2a privacy rule by construction.
class ElectrumServersAdapter implements ElectrumServersPort {
  final ElectrumServerRepository _serverRepository;
  final ElectrumSettingsRepository _settingsRepository;
  final SettingsRepository _appSettingsRepository;
  final ElectrumTorSessionPort _torSessionPort;

  ElectrumServersAdapter({
    required this._serverRepository,
    required this._settingsRepository,
    required this._appSettingsRepository,
    required this._torSessionPort,
  });

  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  }) async {
    // Resolve the active set + settings exactly once per call. The active
    // set is the chokepoint: when a custom server is configured this list
    // contains only custom servers, so the loop can never reach a default.
    final (serversResult, settingsResult, appSettings) = await (
      _serverRepository.fetchActiveServers(network: network),
      _settingsRepository.fetchByNetwork(network),
      _appSettingsRepository.fetch(),
    ).wait;

    final servers = serversResult.fold(
      (value) => value,
      (failure) => throw Exception(
        failure.logMessage ?? 'Failed to fetch active electrum servers',
      ),
    );
    final settings = settingsResult.fold(
      (value) => value,
      (failure) => throw Exception(
        failure.logMessage ?? 'Failed to fetch electrum settings',
      ),
    );

    if (servers.isEmpty) {
      throw NoElectrumServersConfiguredException(network);
    }

    final connections = servers
        .map(
          (server) => ElectrumConnection(
            url: server.url,
            retry: settings.retry,
            timeout: settings.timeout,
            stopGap: settings.stopGap,
            validateDomain: settings.validateDomain,
            isCustom: server.isCustom,
            socks5: settings.socks5,
          ),
        )
        .toList();

    return runElectrumFallback<ElectrumConnection, T>(
      servers: connections,
      urlOf: (c) => c.url,
      isCustomOf: (c) => c.isCustom,
      operation: (connection) async {
        final route = await _torSessionPort.open(
          network: network,
          serverUrl: connection.url,
          externalProxyEnabled: appSettings.useTorProxy,
          externalProxyPort: appSettings.torProxyPort,
        );
        try {
          return await operation(
            connection.withSocks5(
              route?.endpoint.authority ?? connection.socks5,
            ),
          );
        } finally {
          await route?.close();
        }
      },
      isTransient: isTransient,
    );
  }
}
