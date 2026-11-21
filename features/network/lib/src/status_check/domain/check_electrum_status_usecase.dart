import 'package:electrum/electrum.dart';
import 'package:bull_tor/tor.dart';

class CheckElectrumStatusUsecase {
  final ElectrumServersPort _electrumServersPort;
  final ServerStatusPort _serverStatusPort;

  CheckElectrumStatusUsecase({
    required this._electrumServersPort,
    required this._serverStatusPort,
  });

  Future<bool> execute(ElectrumServerNetwork serverNetwork) async {
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
            // The configured clearnet timeout is seeded at 5s. Onion routes
            // raise it to the shared 30s minimum used by the real BDK sync.
            timeout: connection.effectiveTimeout,
            retry: connection.retry,
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
