import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:bull_tor/src/data/dart_io_socket_adapter.dart';
import 'package:bull_tor/src/data/external_socks_tor_backend.dart';
import 'package:bull_tor/src/domain/ports/socket_port.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_tor/tor_adapter.dart';

void main() {
  TorProxyEndpoint loopback(int port) =>
      TorProxyEndpoint(host: InternetAddress.loopbackIPv4.address, port: port);

  ExternalSocksTorBackend backend([SocketPort? sockets]) =>
      ExternalSocksTorBackend(
        sockets ?? DartIoSocketAdapter(),
        const TorLogger(),
        probeTimeout: const Duration(milliseconds: 200),
      );

  Future<ServerSocket> serve(void Function(Socket socket) onClient) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen(onClient);
    return server;
  }

  Matcher failsWith(TorExternalProxyProblem problem) => throwsA(
    isA<TorBackendException>().having(
      (error) => (error.failure as TorExternalProxyUnavailableFailure).problem,
      'problem',
      problem,
    ),
  );

  test('accepts a SOCKS5 greeting split across TCP packets', () async {
    final server = await serve((socket) async {
      await socket.first;
      socket.add([0x05]);
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      socket.add([0x00]);
      await socket.flush();
      await socket.close();
    });

    await expectLater(backend().verify(loopback(server.port)), completes);
  });

  test('reports a closed port as refused', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();

    await expectLater(
      backend().verify(loopback(port)),
      failsWith(TorExternalProxyProblem.refused),
    );
  });

  test('reports a listener that never answers as a timeout', () async {
    final clients = <Socket>[];
    addTearDown(() async {
      for (final client in clients) {
        client.destroy();
      }
    });
    final server = await serve(clients.add);

    await expectLater(
      backend().verify(loopback(server.port)),
      failsWith(TorExternalProxyProblem.timeout),
    );
  });

  test('reports a connect timeout as a timeout', () async {
    await expectLater(
      backend(
        _ThrowingSocketPort(const SocketException('Connection timed out')),
      ).verify(loopback(9050)),
      failsWith(TorExternalProxyProblem.timeout),
    );
  });

  test('reports a service that answers something else as not SOCKS5', () async {
    final server = await serve((socket) async {
      await socket.first;
      socket.write('HTTP/1.1 400 Bad Request\r\n\r\n');
      await socket.flush();
      await socket.close();
    });

    await expectLater(
      backend().verify(loopback(server.port)),
      failsWith(TorExternalProxyProblem.notSocks5),
    );
  });

  test(
    'reports a service that hangs up on the greeting as not SOCKS5',
    () async {
      final server = await serve((socket) async {
        await socket.first;
        await socket.close();
      });

      await expectLater(
        backend().verify(loopback(server.port)),
        failsWith(TorExternalProxyProblem.notSocks5),
      );
    },
  );
}

final class _ThrowingSocketPort implements SocketPort {
  final Object error;

  _ThrowingSocketPort(this.error);

  @override
  Future<SocketConnection> connect(
    String host,
    int port, {
    Duration? timeout,
  }) => Future.error(error);
}
