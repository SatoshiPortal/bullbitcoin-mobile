import 'dart:async';
import 'dart:io';

import 'package:socks5_proxy/socks_client.dart';
import 'package:tor/tor.dart';

final class ElectrumSocketConnector {
  const ElectrumSocketConnector();

  Future<Socket> connect({
    required Uri server,
    required Duration timeout,
    TorProxyEndpoint? proxy,
    bool allowBadCertificate = false,
  }) async {
    if (proxy == null) {
      if (server.scheme == 'ssl') {
        return SecureSocket.connect(
          server.host,
          server.port,
          timeout: timeout,
          onBadCertificate: allowBadCertificate ? (_) => true : null,
        );
      }
      return Socket.connect(server.host, server.port, timeout: timeout);
    }

    final connectFuture = SocksTCPClient.connect(
      [ProxySettings(InternetAddress(proxy.host), proxy.port, password: null)],
      // Preserve the hostname so DNS resolution happens behind the proxy.
      InternetAddress(server.host, type: InternetAddressType.unix),
      server.port,
    );
    try {
      final socksSocket = await connectFuture.timeout(timeout);
      if (server.scheme != 'ssl') return socksSocket;
      try {
        return await socksSocket
            .secure(
              server.host,
              onBadCertificate: allowBadCertificate ? (_) => true : null,
            )
            .timeout(timeout);
      } catch (_) {
        socksSocket.destroy();
        rethrow;
      }
    } on TimeoutException {
      unawaited(
        connectFuture.then<void>((socket) => socket.destroy(), onError: (_) {}),
      );
      rethrow;
    }
  }
}
