import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class ServerStatusAdapter implements ServerStatusPort {
  const ServerStatusAdapter();

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
    bool useTorProxy = false,
    int torProxyPort = 9050,
  }) async {
    try {
      if (url.isEmpty) return ElectrumServerStatus.unknown;

      final uri = _parseUrl(url);
      if (uri == null) return ElectrumServerStatus.offline;

      final effectiveTimeout = _resolveTimeout(uri, timeout);

      final isConnectable = useTorProxy
          ? await _checkThroughSocks5(
              uri: uri,
              proxyPort: torProxyPort,
              timeoutSeconds: effectiveTimeout,
            )
          : await _checkRawSocket(uri: uri, timeoutSeconds: effectiveTimeout);

      return isConnectable
          ? ElectrumServerStatus.online
          : ElectrumServerStatus.offline;
    } catch (e) {
      log.severe(
        message: 'Error checking server socket for $url',
        error: e,
        trace: StackTrace.current,
      );
      return ElectrumServerStatus.offline;
    }
  }

  @override
  Future<ElectrumServerStatus> checkElectrum({
    required String url,
    required ElectrumServerNetwork network,
    int? timeout,
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
    final isOnion = uri.host.endsWith('.onion');
    return timeout ?? (isOnion ? 30 : 5);
  }

  /// Sends a JSON-RPC request and returns the raw response line.
  /// [SecureSocket] extends [Socket], so both branches share the same
  /// write/read logic after construction.
  Future<String> _sendRequest({
    required Uri uri,
    required String request,
    required int timeoutSeconds,
  }) async {
    final Socket socket = uri.scheme == 'ssl'
        ? await SecureSocket.connect(
            uri.host,
            uri.port,
            timeout: Duration(seconds: timeoutSeconds),
            onBadCertificate: (_) => true, // accept self-signed certs
          )
        : await Socket.connect(
            uri.host,
            uri.port,
            timeout: Duration(seconds: timeoutSeconds),
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

  Future<bool> _checkRawSocket({
    required Uri uri,
    required int timeoutSeconds,
  }) async {
    try {
      final socket = await Socket.connect(
        uri.host,
        uri.port,
        timeout: Duration(seconds: timeoutSeconds),
      );
      socket.destroy();
      return true;
    } on SocketException catch (e) {
      log.warning('Socket connection failed for $uri - $e');
      return false;
    } catch (e) {
      log.severe(
        message: 'Unexpected error checking socket for $uri',
        error: e,
        trace: StackTrace.current,
      );
      return false;
    }
  }

  /// Checks connectivity through a SOCKS5 proxy (used for Tor).
  Future<bool> _checkThroughSocks5({
    required Uri uri,
    required int proxyPort,
    required int timeoutSeconds,
  }) async {
    Socket? socket;
    StreamSubscription<List<int>>? subscription;
    try {
      socket = await Socket.connect(
        '127.0.0.1',
        proxyPort,
        timeout: Duration(seconds: timeoutSeconds),
      );

      final handshakeCompleter = Completer<List<int>>();
      final connectCompleter = Completer<List<int>>();
      var isHandshakeDone = false;

      subscription = socket.listen(
        (List<int> data) {
          if (!isHandshakeDone) {
            handshakeCompleter.complete(data);
            isHandshakeDone = true;
          } else {
            connectCompleter.complete(data);
          }
        },
        onError: (Object error) {
          if (!handshakeCompleter.isCompleted) {
            handshakeCompleter.completeError(error);
          }
          if (!connectCompleter.isCompleted) {
            connectCompleter.completeError(error);
          }
        },
        cancelOnError: true,
      );

      // SOCKS5 handshake: version 5, 1 auth method (no auth)
      socket.add([0x05, 0x01, 0x00]);

      final handshakeResponse = await handshakeCompleter.future.timeout(
        Duration(seconds: timeoutSeconds),
      );

      if (handshakeResponse.length < 2 || handshakeResponse[0] != 0x05) {
        log.warning('Invalid SOCKS5 handshake response');
        return false;
      }

      socket.add(_buildSocks5ConnectRequest(uri));

      final connectResponse = await connectCompleter.future.timeout(
        Duration(seconds: timeoutSeconds),
      );

      if (connectResponse.length < 2 ||
          connectResponse[0] != 0x05 ||
          connectResponse[1] != 0x00) {
        log.severe(
          error: Exception('SOCKS5 connection failed'),
          trace: StackTrace.current,
        );
        return false;
      }

      return true;
    } catch (e) {
      log.severe(
        message: 'SOCKS5 connection check failed for $uri',
        error: e,
        trace: StackTrace.current,
      );
      return false;
    } finally {
      await subscription?.cancel();
      socket?.destroy();
    }
  }

  /// Builds a SOCKS5 CONNECT request.
  /// Format: [version, command, reserved, address_type, address, port]
  List<int> _buildSocks5ConnectRequest(Uri uri) {
    final request = <int>[
      0x05, // SOCKS version 5
      0x01, // CONNECT command
      0x00, // Reserved
      0x03, // Address type: domain name
    ];
    final hostBytes = uri.host.codeUnits;
    request.add(hostBytes.length);
    request.addAll(hostBytes);
    request.add((uri.port >> 8) & 0xFF);
    request.add(uri.port & 0xFF);
    return request;
  }
}
