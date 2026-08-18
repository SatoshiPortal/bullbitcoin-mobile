import 'dart:io';

import 'package:test/test.dart';
import 'package:bull_tor/src/data/dart_io_socket_adapter.dart';
import 'package:bull_tor/src/data/external_socks_tor_backend.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_tor/tor_adapter.dart';

void main() {
  test('accepts a SOCKS5 greeting split across TCP packets', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close());
    server.listen((socket) async {
      await socket.first;
      socket.add([0x05]);
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      socket.add([0x00]);
      await socket.flush();
      await socket.close();
    });

    final backend = ExternalSocksTorBackend(
      DartIoSocketAdapter(),
      const TorLogger(),
    );
    final endpoint = TorProxyEndpoint(
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
    );

    await expectLater(backend.verify(endpoint), completes);
  });
}
