import 'dart:io';

import 'package:socks5_proxy/socks_client.dart';

import '../domain/entities/tor_proxy_endpoint.dart';
import '../domain/tor_failure.dart';

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

  HttpClient create(TorProxyEndpoint endpoint) {
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
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      final connection = SocksTCPClient.connect(
        [ProxySettings(address, endpoint.port, password: null)],
        InternetAddress(uri.host, type: InternetAddressType.unix),
        uri.port,
      );
      final Future<Socket> socket = uri.scheme == 'https'
          ? connection.then((value) => value.secure(uri.host))
          : connection;
      return ConnectionTask.fromSocket(socket, () {
        // Cancellation owns cleanup, not the request's error reporting.
        // The original socket future still delivers failures to HttpClient.
        socket.then((value) => value.destroy()).ignore();
      });
    };
    return client;
  }
}
