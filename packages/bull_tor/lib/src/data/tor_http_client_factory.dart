import 'dart:io';

import 'package:socks5_proxy/socks_client.dart';

import '../domain/entities/tor_proxy_endpoint.dart';
import '../domain/tor_failure.dart';
import '../domain/tor_connection_failure_recorder.dart';

/// Builds an HTTP client for an already-selected Tor route.
///
/// [endpoint] is deliberately non-nullable. Accepting null meant "return a
/// plain, unproxied client", and the only consumer is the RecoverBull key
/// server — an onion address. A caller that passed null would have shipped its
/// request over clearnet to a hidden-service name, so the route is a
/// requirement the compiler enforces rather than a default the caller can
/// forget.
final class TorHttpClientFactory {
  const TorHttpClientFactory();

  HttpClient create(
    TorProxyEndpoint endpoint, {
    TorConnectionFailureRecorder? failureRecorder,
  }) {
    // The proxy endpoint is loopback by product contract. The destination
    // hostname is intentionally left to socks5_proxy so SOCKS5 can send it as
    // ATYP DOMAINNAME instead of resolving it on the device.
    final address = InternetAddress.tryParse(endpoint.host);
    if (address == null) {
      throw TorBackendException(
        TorUnexpectedFailure(
          'SOCKS5 proxy host is not an IP literal: ${endpoint.host}',
        ),
      );
    }

    final client = HttpClient();
    final recorder = failureRecorder;
    final proxy = ProxySettings(address, endpoint.port, password: null);
    client.connectionFactory = (uri, _, _) {
      Future<ConnectionTask<Socket>> delegate() async {
        final socket = SocksTCPClient.connect(
          [proxy],
          InternetAddress(uri.host, type: InternetAddressType.unix),
          uri.port,
        );
        if (uri.scheme == 'https') {
          final Future<SecureSocket> secureSocket;
          return ConnectionTask.fromSocket(
            secureSocket = (await socket).secure(uri.host),
            () async => (await secureSocket).close().ignore(),
          );
        }
        return ConnectionTask.fromSocket(
          socket,
          () async => (await socket).close().ignore(),
        );
      }

      return recorder == null
          ? delegate()
          : recorder.wrap((_, _, _) => delegate())(uri, null, null);
    };
    return client;
  }
}
