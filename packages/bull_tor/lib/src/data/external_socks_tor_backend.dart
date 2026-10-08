import 'dart:async';
import 'dart:io';

import '../domain/entities/tor_proxy_endpoint.dart';
import '../domain/ports/external_tor_port.dart';
import '../domain/ports/socket_port.dart';
import '../domain/tor_failure.dart';
import 'tor_logger.dart';

/// Verifies a user-managed SOCKS5 proxy without claiming bootstrap data
/// that SOCKS5 does not expose.
///
/// The probe stops at the method negotiation on purpose: a CONNECT through
/// the proxy would prove more, but it would send traffic over Tor on every
/// check. What it can tell apart is where the exchange stopped.
final class ExternalSocksTorBackend implements ExternalTorPort {
  final SocketPort _socketPort;
  final TorLogger _log;
  final Duration _probeTimeout;

  const ExternalSocksTorBackend(
    this._socketPort,
    this._log, {
    this._probeTimeout = const Duration(seconds: 3),
  });

  @override
  Future<void> verify(TorProxyEndpoint endpoint) async {
    final SocketConnection socket;
    try {
      socket = await _socketPort.connect(
        endpoint.host,
        endpoint.port,
        timeout: _probeTimeout,
      );
    } catch (error) {
      throw _unavailable(error, _isTimeout(error) ? .timeout : .refused);
    }

    try {
      socket.add([0x05, 0x01, 0x00]);
      final response = await socket.read(2, timeout: _probeTimeout);
      if (response.length < 2 || response[0] != 0x05 || response[1] != 0x00) {
        throw _unavailable(
          'Endpoint did not accept an unauthenticated SOCKS5 greeting',
          .notSocks5,
        );
      }
      _log.config('External Tor proxy available');
    } on TorBackendException {
      rethrow;
    } on TimeoutException catch (error) {
      throw _unavailable(error, .timeout);
    } catch (error) {
      // The connection opened, then closed or failed mid-greeting: whatever
      // listens there does not speak SOCKS5.
      throw _unavailable(error, .notSocks5);
    } finally {
      await socket.close();
    }
  }

  /// Dart reports its own connect timeout as a SocketException without an OS
  /// error, unlike a refusal, which always carries one.
  static bool _isTimeout(Object error) => switch (error) {
    TimeoutException() => true,
    SocketException(:final osError, :final message) =>
      osError == null && message.contains('timed out'),
    _ => false,
  };

  static TorBackendException _unavailable(
    Object reason,
    TorExternalProxyProblem problem,
  ) => TorBackendException(
    TorExternalProxyUnavailableFailure(reason.toString(), problem),
  );
}
