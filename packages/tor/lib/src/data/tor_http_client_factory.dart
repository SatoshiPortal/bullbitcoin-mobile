import 'dart:io';

import 'package:socks5_proxy/socks_client.dart';

import '../domain/entities/tor_proxy_endpoint.dart';

/// Builds an HTTP client for an already-selected Tor route.
final class TorHttpClientFactory {
  const TorHttpClientFactory();

  HttpClient create(TorProxyEndpoint? endpoint) {
    final client = HttpClient();
    if (endpoint == null) return client;
    SocksTCPClient.assignToHttpClient(client, [
      ProxySettings(
        InternetAddress(endpoint.host),
        endpoint.port,
        password: null,
      ),
    ]);
    return client;
  }
}
