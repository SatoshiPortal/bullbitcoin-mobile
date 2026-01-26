import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/utils/logger.dart';

class SocketConnectivityDatasource {
  const SocketConnectivityDatasource();

  /// Attempts a raw socket connection to verify server reachability
  /// If useTorProxy is true, connects through SOCKS5 proxy to verify Tor connectivity
  Future<bool> checkConnection({
    required String host,
    required int port,
    int timeoutSeconds = 5,
    bool useTorProxy = false,
    int torProxyPort = 9050,
  }) async {
    try {
      if (host.isEmpty || port == 0) {
        return false;
      }

      if (useTorProxy) {
        return await _checkThroughSocks5(
          host: host,
          port: port,
          proxyPort: torProxyPort,
          timeoutSeconds: timeoutSeconds,
        );
      }

      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(seconds: timeoutSeconds),
      );

      socket.destroy();
      return true;
    } on SocketException catch (e) {
      log.warning('Socket connection failed for $host:$port - $e');
      return false;
    } catch (e) {
      log.severe(
        'Unexpected error checking socket connection: $e',
        trace: StackTrace.current,
      );
      return false;
    }
  }

  /// Check connectivity through SOCKS5 proxy
  Future<bool> _checkThroughSocks5({
    required String host,
    required int port,
    required int proxyPort,
    required int timeoutSeconds,
  }) async {
    Socket? socket;
    StreamSubscription<List<int>>? subscription;
    try {
      // Connect to SOCKS5 proxy
      socket = await Socket.connect(
        '127.0.0.1',
        proxyPort,
        timeout: Duration(seconds: timeoutSeconds),
      );

      // Create a completer to handle async responses
      final handshakeCompleter = Completer<List<int>>();
      final connectCompleter = Completer<List<int>>();
      var isHandshakeDone = false;

      // Listen to socket responses
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

      // Wait for handshake response
      final handshakeResponse = await handshakeCompleter.future.timeout(
        Duration(seconds: timeoutSeconds),
      );

      // Check valid SOCKS5 response [0x05, 0x00]
      if (handshakeResponse.length < 2 || handshakeResponse[0] != 0x05) {
        log.warning('Invalid SOCKS5 handshake response');
        return false;
      }

      // SOCKS5 CONNECT command to target host
      final connectRequest = _buildSocks5ConnectRequest(host, port);
      socket.add(connectRequest);

      // Wait for connect response
      final connectResponse = await connectCompleter.future.timeout(
        Duration(seconds: timeoutSeconds),
      );

      // Check if connection succeeded [0x05, 0x00, ...]
      if (connectResponse.length < 2 ||
          connectResponse[0] != 0x05 ||
          connectResponse[1] != 0x00) {
        log.severe(
          'SOCKS5 connection to $host:$port failed',
          trace: StackTrace.current,
        );
        return false;
      }

      return true;
    } catch (e) {
      log.severe(
        'SOCKS5 connection check failed for $host:$port - $e',
        trace: StackTrace.current,
      );
      return false;
    } finally {
      await subscription?.cancel();
      socket?.destroy();
    }
  }

  /// Build SOCKS5 CONNECT request
  /// Format: [version, command, reserved, address_type, address, port]
  List<int> _buildSocks5ConnectRequest(String host, int port) {
    final request = <int>[
      0x05, // SOCKS version 5
      0x01, // CONNECT command
      0x00, // Reserved
      0x03, // Address type: domain name
    ];

    // Add domain name length and domain
    final hostBytes = host.codeUnits;
    request.add(hostBytes.length);
    request.addAll(hostBytes);

    // Add port (2 bytes, big-endian)
    request.add((port >> 8) & 0xFF);
    request.add(port & 0xFF);

    return request;
  }
}
