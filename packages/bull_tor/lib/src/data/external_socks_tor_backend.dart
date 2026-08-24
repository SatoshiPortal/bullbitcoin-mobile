import 'dart:async';

import '../domain/entities/tor_proxy_endpoint.dart';
import '../domain/ports/external_tor_port.dart';
import '../domain/ports/socket_port.dart';
import '../domain/tor_failure.dart';
import 'tor_logger.dart';

/// Verifies a user-managed proxy such as Orbot without claiming bootstrap data
/// that SOCKS5 does not expose.
final class ExternalSocksTorBackend implements ExternalTorPort {
  final SocketPort _socketPort;
  final TorLogger _log;

  const ExternalSocksTorBackend(this._socketPort, this._log);

  @override
  Future<void> verify(TorProxyEndpoint endpoint) async {
    SocketConnection? socket;
    try {
      socket = await _socketPort.connect(
        endpoint.host,
        endpoint.port,
        timeout: const Duration(seconds: 3),
      );
      socket.add([0x05, 0x01, 0x00]);
      final response = await socket.read(
        2,
        timeout: const Duration(seconds: 3),
      );
      if (response.length < 2 || response[0] != 0x05 || response[1] != 0x00) {
        throw const TorBackendException(
          TorExternalProxyUnavailableFailure(
            'Endpoint did not accept an unauthenticated SOCKS5 greeting',
          ),
        );
      }
      _log.config('External Tor proxy available on $endpoint');
    } on TorBackendException {
      rethrow;
    } on TimeoutException catch (error) {
      throw TorBackendException(
        TorExternalProxyUnavailableFailure(error.toString()),
      );
    } catch (error) {
      throw TorBackendException(
        TorExternalProxyUnavailableFailure(error.toString()),
      );
    } finally {
      await socket?.close();
    }
  }
}
