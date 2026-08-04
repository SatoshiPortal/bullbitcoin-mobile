import 'dart:io';

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
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bull_tor/tor.dart';

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
        final ElectrumTorRoute? route;
        try {
          route = await _torSessionPort.open(
            network: network,
            serverUrl: connection.url,
            externalProxyEnabled: appSettings.useTorProxy,
            externalProxyPort: appSettings.torProxyPort,
          );
        } catch (_) {
          // Opening the route can fail on its own — an embedded bootstrap that
          // never completes is arguably the likeliest way an onion server
          // becomes unusable. That makes *this server* unroutable, not the whole
          // active set, so it has to surface as the type the fallback loop
          // already treats as transient. Otherwise a caller that narrows
          // `isTransient` to its own error rethrows immediately and never tries
          // the healthy clearnet default sitting next in the set.
          throw OnionServerWithoutTorException(connection.url);
        }
        try {
          // Precedence matters and predates this stack: an explicitly persisted
          // SOCKS setting wins over the Tor proxy toggle, which is the old
          // `settings.socks5 ?? torProxy` semantics. The onion route comes first
          // because it is the only one that can carry a hidden service.
          final routed = connection.withSocks5(
            route?.endpoint.authority ??
                connection.socks5 ??
                _clearnetProxy(network, appSettings),
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
          } catch (_) {
            // Route cleanup must not turn a successful server operation into a
            // fallback attempt.
          }
        }
      },
      // An unroutable onion server is skipped, not fatal: the rest of the
      // active set may still be reachable. Callers narrowing `isTransient` to
      // their own error type must not turn that into a hard stop.
      isTransient: isTransient == null
          ? null
          : (error) =>
                error is OnionServerWithoutTorException || isTransient(error),
    );
  }

  /// The external proxy for a *clearnet* Bitcoin server, when one is configured.
  ///
  /// Onion servers get a dedicated route from [_torSessionPort]; this covers
  /// everything else. Without it, enabling the Tor proxy would silently stop
  /// protecting the default Electrum servers — which are clearnet, and are
  /// exactly what a user hides their IP from by turning Orbot on. The setting
  /// has always been documented as applying to Bitcoin, not to onions only.
  ///
  /// Liquid stays excluded, as it always has been.
  static String? _clearnetProxy(
    ElectrumServerNetwork network,
    SettingsEntity appSettings,
  ) {
    if (network.isLiquid || !appSettings.useTorProxy) return null;
    return TorProxyEndpoint(
      host: InternetAddress.loopbackIPv4.address,
      port: appSettings.torProxyPort,
    ).authority;
  }

  static bool _isUnroutableOnion(ElectrumConnection connection) =>
      ElectrumServerUrl(connection.url).isOnion &&
      (connection.socks5?.isEmpty ?? true);
}
