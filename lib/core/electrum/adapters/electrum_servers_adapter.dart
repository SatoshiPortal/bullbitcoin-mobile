import 'package:bb_mobile/core/electrum/domain/electrum_fallback_runner.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_tor_session_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_url.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

/// Concrete [ElectrumServersPort]. Owns the only place in the app where the
/// active server list is resolved, merged with Electrum and proxy settings, and
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
    final (serversResult, settingsResult) = await (
      _serverRepository.fetchActiveServers(network: network),
      _settingsRepository.fetchByNetwork(network),
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
    final appSettings = await _appSettingsRepository.fetch();

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
        ElectrumTorRoute? route;
        try {
          route = await _torSessionPort.open(
            network: network,
            serverUrl: connection.url,
            isCustom: connection.isCustom,
            externalProxyEnabled: appSettings.useTorProxy,
            externalProxyPort: appSettings.torProxyPort,
          );
        } on Exception {
          // Opening the route can fail on its own — an embedded bootstrap that
          // never completes is arguably the likeliest way an onion server
          // becomes unusable. That makes *this server* unroutable, not the whole
          // active set, so it has to surface as the type the fallback loop
          // already treats as transient. Otherwise a caller that narrows
          // `isTransient` to its own error rethrows immediately and never tries
          // the healthy clearnet default sitting next in the set.
          throw _withoutTor(
            connection.url,
            isOnion: ElectrumServerUrl(connection.url).isOnion,
          );
        }
        try {
          // Precedence matters and predates this stack: an explicitly persisted
          // SOCKS setting wins over the Tor proxy toggle, which is the old
          // `settings.socks5 ?? torProxy` semantics. The onion route comes first
          // because it is the only one that can carry a hidden service. For a
          // clearnet server, some session implementations return no scoped
          // route, so the already verified external route remains the fallback.
          final routed = connection.withSocks5(
            route?.endpoint.authority ?? connection.socks5,
          );
          // The chokepoint that makes the invariant unavoidable: not every
          // consumer goes through our socket connector — BDK and LWK open
          // their own — so refusing here is the only check they all share.
          if (_isUnroutableOnion(routed)) {
            throw OnionServerWithoutTorException(routed.url);
          }
          return await operation(routed);
        } finally {
          try {
            await route?.close();
          } on Exception {
            // Route cleanup must not turn a successful server operation into a
            // fallback attempt.
          }
        }
      },
      // A server blocked by missing Tor is skipped, not fatal: the rest of the
      // active set may still be reachable. Callers narrowing `isTransient` to
      // their own error type must not turn that into a hard stop.
      isTransient: isTransient == null
          ? null
          : (error) =>
                error is OnionServerWithoutTorException ||
                error is ClearnetServerWithoutConfiguredTorException ||
                isTransient(error),
    );
  }

  static bool _isUnroutableOnion(ElectrumConnection connection) =>
      ElectrumServerUrl(connection.url).isOnion &&
      (connection.socks5?.isEmpty ?? true);

  static ElectrumFallbackException _withoutTor(
    String url, {
    required bool isOnion,
  }) => isOnion
      ? OnionServerWithoutTorException(url)
      : ClearnetServerWithoutConfiguredTorException(url);
}
