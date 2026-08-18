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
    // `ProxySettings` takes a resolved address, but `TorProxyEndpoint` accepts
    // any non-empty host because the Electrum advanced options let one be typed
    // by hand. Rejecting a non-literal here as a modeled failure keeps that
    // combination from surfacing as a bare `ArgumentError` from `dart:io`.
    final address = InternetAddress.tryParse(endpoint.host);
    if (address == null) {
      throw TorBackendException(
        TorUnexpectedFailure(
          'SOCKS5 proxy host is not an IP literal: ${endpoint.host}',
        ),
      );
    }

    final client = HttpClient();
    SocksTCPClient.assignToHttpClient(client, [
      ProxySettings(address, endpoint.port, password: null),
    ]);
    return client;
  }
}
