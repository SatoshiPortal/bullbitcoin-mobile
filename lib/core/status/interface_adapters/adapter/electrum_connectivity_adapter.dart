import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_tor/tor.dart';

class ElectrumConnectivityAdapter implements ElectrumConnectivityPort {
  final ElectrumServersPort _electrumServersPort;
  final ServerStatusPort _serverStatusPort;

  ElectrumConnectivityAdapter({
    required this._electrumServersPort,
    required this._serverStatusPort,
  });

  @override
  Future<bool> checkServersInUseAreOnlineForNetwork(Network network) async {
    final serverNetwork = ElectrumServerNetwork.fromEnvironment(
      isTestnet: network.isTestnet,
      isLiquid: network.isLiquid,
    );

    try {
      return await _electrumServersPort.runWithFallback<bool>(
        network: serverNetwork,
        operation: (connection) async {
          // An empty string is "no proxy", not a malformed one: settings persist
          // `''` in practice, and treating it as malformed marked every server
          // offline.
          final socks5 = connection.socks5?.trim();
          final proxyEndpoint = switch (socks5) {
            null || '' => null,
            final proxy =>
              TorProxyEndpoint.tryParse(proxy) ??
                  (throw const _ElectrumServerOfflineException()),
          };
          final status = await _serverStatusPort.checkElectrum(
            url: connection.url,
            network: serverNetwork,
            // The user's own setting, so "online" here means the sync can
            // actually reach the server too.
            validateDomain: connection.validateDomain,
            // Deliberately not `connection.timeout`: that is the user's clearnet
            // ceiling, seeded at 5s, and it would override the longer onion
            // default. Five seconds cannot cover a SOCKS handshake, a circuit
            // build, TLS and a JSON-RPC round trip, so a healthy onion server
            // would report offline and trip the Tor error banner.
            timeout: proxyEndpoint == null ? connection.timeout : null,
            proxyEndpoint: proxyEndpoint,
          );
          if (status == ElectrumServerStatus.online) return true;
          throw const _ElectrumServerOfflineException();
        },
        isTransient: (error) => error is _ElectrumServerOfflineException,
      );
    } on Exception {
      return false;
    }
  }
}

final class _ElectrumServerOfflineException implements Exception {
  const _ElectrumServerOfflineException();
}
