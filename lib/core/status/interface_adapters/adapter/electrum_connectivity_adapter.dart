import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:tor/tor.dart';

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
          final proxyEndpoint = switch (connection.socks5) {
            null => null,
            final proxy =>
              TorProxyEndpoint.tryParse(proxy) ??
                  (throw const _ElectrumServerOfflineException()),
          };
          final status = await _serverStatusPort.checkElectrum(
            url: connection.url,
            network: serverNetwork,
            timeout: connection.timeout,
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
