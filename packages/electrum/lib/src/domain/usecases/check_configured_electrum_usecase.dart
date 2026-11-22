import 'package:bull_tor/tor.dart';
import 'package:primitives/primitives.dart';

import '../electrum_failure.dart';
import '../electrum_server_network.dart';
import '../errors/electrum_fallback_exception.dart';
import '../ports/electrum_servers_port.dart';
import '../ports/server_status_port.dart';
import '../value_objects/electrum_server_status.dart';

Future<Result<ElectrumServerStatus, ElectrumFailure>> checkConfiguredElectrum(
  RunElectrumWithFallback runWithFallback,
  ServerStatusPort probe,
  ElectrumServerNetwork serverNetwork,
) async {
  try {
    return await runWithFallback<ElectrumServerStatus>(
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
        final status = await probe.checkElectrum(
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
        if (status == ElectrumServerStatus.online) return status;
        throw const _ElectrumServerOfflineException();
      },
      isTransient: (error) => error is _ElectrumServerOfflineException,
    );
  } on NoElectrumServersConfiguredException {
    return const Err(ElectrumLoadFailure());
  } on AllElectrumServersFailedException {
    return const Err(ElectrumServerUnreachableFailure());
  } on Exception {
    return const Err(ElectrumUnexpectedFailure());
  }
}

final class _ElectrumServerOfflineException implements Exception {
  const _ElectrumServerOfflineException();
}
