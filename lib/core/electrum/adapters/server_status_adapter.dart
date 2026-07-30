import 'dart:convert';

import 'package:bb_mobile/core/electrum/data/electrum_socket_connector.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_url.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:tor/tor.dart';

class ServerStatusAdapter implements ServerStatusPort {
  final ElectrumSocketConnector _socketConnector;

  const ServerStatusAdapter(this._socketConnector);

  /// Bitcoin pizza day — first real-world BTC purchase, May 22 2010.
  static const _bitcoinMainnetProbeTxid =
      'cca7507897abc89628f450e8b1e0c6fca4ec3f7b34cccf55f3f531c659ff4d79';

  /// First quantum-proof signature on Liquid mainnet.
  static const _liquidMainnetProbeTxid =
      'e079f31c58655e7b37477c6bb8f23aafaa942a86fe8c47f2970840a2c0829239';

  @override
  Future<ElectrumServerStatus> checkSocket({
    required String url,
    int? timeout,
    TorProxyEndpoint? proxyEndpoint,
  }) async {
    try {
      if (url.isEmpty) return ElectrumServerStatus.unknown;

      final uri = _parseUrl(url);
      if (uri == null) return ElectrumServerStatus.offline;

      final effectiveTimeout = _resolveTimeout(uri, timeout);

      final socket = await _socketConnector.connect(
        server: uri,
        proxy: proxyEndpoint,
        timeout: Duration(seconds: effectiveTimeout),
        allowBadCertificate: true,
      );
      socket.destroy();
      return ElectrumServerStatus.online;
    } catch (e) {
      // A server we cannot reach is the expected answer of this check, not a
      // fault: `severe` would report every offline server to Sentry.
      log.warning('Socket check failed for $url - $e');
      return ElectrumServerStatus.offline;
    }
  }

  @override
  Future<ElectrumServerStatus> checkElectrum({
    required String url,
    required ElectrumServerNetwork network,
    int? timeout,
    TorProxyEndpoint? proxyEndpoint,
  }) async {
    try {
      if (url.isEmpty) return ElectrumServerStatus.unknown;

      final uri = _parseUrl(url);
      if (uri == null) return ElectrumServerStatus.offline;

      final effectiveTimeout = _resolveTimeout(uri, timeout);
      final probeTxid = _probeTxidFor(network);

      // Testnet has no stable probe tx — fall back to a server.version
      // handshake which only proves protocol compliance, not chain data.
      final request = probeTxid == null
          ? '{"id":1,"method":"server.version","params":["bb-mobile","1.4"]}\n'
          : '{"id":1,"method":"blockchain.transaction.get","params":["$probeTxid",false]}\n';

      final response = await _sendRequest(
        uri: uri,
        request: request,
        timeoutSeconds: effectiveTimeout,
        proxyEndpoint: proxyEndpoint,
      );

      if (response.isEmpty) return ElectrumServerStatus.offline;

      final json = jsonDecode(response) as Map<String, dynamic>;
      final result = json['result'];
      final isAlive = probeTxid == null
          ? result != null
          : result is String && result.isNotEmpty;
      return isAlive
          ? ElectrumServerStatus.online
          : ElectrumServerStatus.offline;
    } catch (e) {
      log.warning('Electrum protocol check failed for $url - $e');
      return ElectrumServerStatus.offline;
    }
  }

  String? _probeTxidFor(ElectrumServerNetwork network) {
    switch (network) {
      case ElectrumServerNetwork.bitcoinMainnet:
        return _bitcoinMainnetProbeTxid;
      case ElectrumServerNetwork.liquidMainnet:
        return _liquidMainnetProbeTxid;
      case ElectrumServerNetwork.bitcoinTestnet:
      case ElectrumServerNetwork.liquidTestnet:
        return null;
    }
  }

  /// Parses a URL string into host, port, and SSL flag.
  /// Returns null if the URL is invalid.
  Uri? _parseUrl(String url) {
    var normalizedUrl = url;
    if (!(url.startsWith('ssl://') || url.startsWith('tcp://'))) {
      normalizedUrl = 'ssl://$url';
    }
    final uri = Uri.parse(normalizedUrl);
    if (uri.host.isEmpty || uri.port == 0) return null;
    return uri;
  }

  /// Onion addresses need longer timeouts due to Tor circuit building.
  /// Default: 5 seconds for clearnet, 30 seconds for .onion addresses.
  int _resolveTimeout(Uri uri, int? timeout) {
    final isOnion = ElectrumServerUrl.isOnionHost(uri.host);
    return timeout ?? (isOnion ? 30 : 5);
  }

  /// Sends a JSON-RPC request and returns the raw response line. Plain, TLS
  /// and proxied sockets all arrive as a [Socket], so the read/write path
  /// below is the same for every transport.
  Future<String> _sendRequest({
    required Uri uri,
    required String request,
    required int timeoutSeconds,
    TorProxyEndpoint? proxyEndpoint,
  }) async {
    final socket = await _socketConnector.connect(
      server: uri,
      proxy: proxyEndpoint,
      timeout: Duration(seconds: timeoutSeconds),
      allowBadCertificate: true,
    );

    try {
      socket.write(request);
      final line = await utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .firstWhere((_) => true, orElse: () => '')
          .timeout(Duration(seconds: timeoutSeconds));
      return line;
    } finally {
      socket.destroy();
    }
  }
}
