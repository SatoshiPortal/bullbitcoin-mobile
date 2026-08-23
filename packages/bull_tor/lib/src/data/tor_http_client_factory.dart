import 'dart:io';

import 'package:socks5_proxy/socks_client.dart';

import '../domain/entities/tor_proxy_endpoint.dart';
import '../domain/tor_failure.dart';

/// Builds an HTTP client for an already-selected Tor route.
///
/// [endpoint] is deliberately non-nullable. Accepting null meant "return a
/// plain, unproxied client". A caller that passed null could ship a request over
/// clearnet, so the route is a requirement the compiler enforces rather than a
/// default the caller can forget.
final class TorHttpClientFactory {
  const TorHttpClientFactory();

  /// Creates a client that can only connect through [endpoint].
  ///
  /// Certificate validation stays enabled unless [allowBadCertificate] is
  /// explicitly selected for a user-controlled server.
  HttpClient create(
    TorProxyEndpoint endpoint, {
    bool allowBadCertificate = false,
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
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      final connection = SocksTCPClient.connect(
        [ProxySettings(address, endpoint.port, password: null)],
        InternetAddress(uri.host, type: InternetAddressType.unix),
        uri.port,
      );
      final Future<Socket> socket = uri.scheme == 'https'
          ? connection.then((value) => value.secure(uri.host, onBadCertificate: allowBadCertificate ? (_) => true : null))
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
