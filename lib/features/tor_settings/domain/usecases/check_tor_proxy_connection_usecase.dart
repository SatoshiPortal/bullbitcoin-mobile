import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core_deprecated/tor/tor_status.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';
import 'package:bb_mobile/features/tor_settings/domain/ports/socket_port.dart';

class CheckTorProxyConnectionUsecase {
  final SocketPort _socketPort;

  const CheckTorProxyConnectionUsecase({required SocketPort socketPort})
    : _socketPort = socketPort;

  /// Checks if a Tor SOCKS5 proxy is running and accessible on the given port
  ///
  /// This performs a SOCKS5 handshake to verify:
  /// 1. The port is open and listening
  /// 2. The service responds as a valid SOCKS5 proxy
  /// 3. The app has permission to connect
  ///
  /// Returns the appropriate [TorStatus] based on the connection check
  Future<TorStatus> execute(int port) async {
    try {
      // Test SOCKS5 proxy functionality by attempting SOCKS5 handshake
      // This verifies both that the port is open AND that our app can use it
      final socket = await _socketPort.connect(
        '127.0.0.1',
        port,
        // TODO: maybe we should give some more time for this?
        timeout: const Duration(seconds: 3),
      );

      try {
        // Send SOCKS5 handshake: version 5, 1 auth method (no auth)
        socket.add([0x05, 0x01, 0x00]);

        // Wait for SOCKS5 response with timeout
        final response = await socket.first.timeout(
          const Duration(seconds: 3),
          onTimeout: () => throw TimeoutException('SOCKS5 handshake timeout'),
        );

        // Valid SOCKS5 response should be [0x05, 0x00] (version 5, no auth)
        if (response.length >= 2 && response[0] == 0x05) {
          // SOCKS5 proxy responded correctly - connection is working
          await socket.close();
          log.config(
            'Tor SOCKS5 proxy is online and accessible at 127.0.0.1:$port',
          );
          return TorStatus.online;
        } else {
          // Unexpected response - port is open but not a valid SOCKS5 proxy
          await socket.close();
          log.warning('Port $port is open but not responding as SOCKS5 proxy');
          return TorStatus.unknown;
        }
      } catch (e) {
        // SOCKS5 handshake failed - likely app doesn't have permission
        await socket.close();
        log.warning(
          'SOCKS5 handshake failed (app may not have permission): $e',
        );
        return TorStatus.offline;
      }
    } on SocketException catch (e) {
      // Connection failed - Tor proxy is not running or not reachable
      log.warning('Tor proxy connection failed: $e');
      return TorStatus.offline;
    } on TimeoutException catch (e) {
      // Connection timeout - Tor proxy is not responding
      log.warning('Tor proxy connection timeout: $e');
      return TorStatus.offline;
    } catch (e) {
      // Other errors - mark as unknown
      log.severe('Unexpected error checking Tor status: $e');
      return TorStatus.unknown;
    }
  }
}
