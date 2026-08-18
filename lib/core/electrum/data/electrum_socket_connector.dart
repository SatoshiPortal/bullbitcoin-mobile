import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_url.dart';
import 'package:socks5_proxy/socks_client.dart';
import 'package:bull_tor/tor.dart';

final class ElectrumSocketConnector {
  const ElectrumSocketConnector();

  Future<Socket> connect({
    required Uri server,
    required Duration timeout,
    TorProxyEndpoint? proxy,
    bool allowBadCertificate = false,
  }) async {
    // Refused rather than attempted: `Socket.connect` would pass the
    // hidden-service name to the system resolver, disclosing it to whoever
    // runs the DNS, and then fail anyway because no resolver answers for
    // `.onion`. Callers reach this connector from several paths, so the check
    // belongs here rather than in each of them.
    if (proxy == null && ElectrumServerUrl.isOnionHost(server.host)) {
      throw OnionServerWithoutTorException(server.host);
    }

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
      // `socks5_proxy` takes an `InternetAddress`, which normally means the
      // name is already resolved — locally, over clearnet DNS. The `unix` type
      // is the one constructor that accepts an arbitrary string without
      // resolving it, so the package emits SOCKS5 ATYP 0x03 (domain name) and
      // the exit relay does the lookup instead. See `hostnameOf` in
      // socks5_proxy's `socks_client.dart`.
      //
      // It is a load-bearing quirk of a third-party package, not an idiom:
      // `electrum_socket_connector_test.dart` pins the resulting wire bytes so
      // an upgrade that changes the behaviour fails a test rather than quietly
      // reintroducing a DNS leak.
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
