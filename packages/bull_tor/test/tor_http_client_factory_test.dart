import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bull_tor/tor.dart';
import 'package:test/test.dart';

void main() {
  test('sends destination hostnames to SOCKS5 as domain names', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final requestSeen = Completer<List<int>>();
    final sockets = <Socket>[];
    server.listen((socket) {
      sockets.add(socket);
      var greeted = false;
      var connected = false;
      var responded = false;
      final bytes = <int>[];
      socket.listen((chunk) {
        bytes.addAll(chunk);
        if (!greeted) {
          if (bytes.length < 2 || bytes.length < 2 + bytes[1]) return;
          bytes.removeRange(0, 2 + bytes[1]);
          greeted = true;
          socket.add([0x05, 0x00]);
        }
        if (!connected) {
          final length = _completeConnectRequestLength(bytes);
          if (length == null) return;
          if (!requestSeen.isCompleted) {
            requestSeen.complete(bytes.sublist(0, length));
          }
          bytes.removeRange(0, length);
          connected = true;
          socket.add([0x05, 0x00, 0x00, 0x01, 127, 0, 0, 1, 0, 80]);
        }
        // A real HTTP server responds after receiving a request. Sending HTTP
        // bytes with the SOCKS reply can strand them in the handshake reader.
        if (!responded && ascii.decode(bytes).contains('\r\n\r\n')) {
          responded = true;
          socket.add(
            ascii.encode(
              'HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n',
            ),
          );
          unawaited(socket.close());
        }
      });
    });
    addTearDown(() {
      for (final socket in sockets) {
        socket.destroy();
      }
      return server.close();
    });

    final proxiedClient = const TorHttpClientFactory().create(
      TorProxyEndpoint(host: '127.0.0.1', port: server.port),
    );
    addTearDown(() => proxiedClient.close(force: true));

    final request = await proxiedClient
        .getUrl(Uri.parse('http://destination.invalid/'))
        .timeout(const Duration(seconds: 5));
    final response = await request.close().timeout(const Duration(seconds: 5));
    expect(response.statusCode, HttpStatus.ok);
    await response.drain<void>().timeout(const Duration(seconds: 5));
    final socksRequest = await requestSeen.future.timeout(
      const Duration(seconds: 5),
    );

    expect(socksRequest[0], 0x05);
    expect(socksRequest[1], 0x01);
    expect(socksRequest[3], 0x03);
    final length = socksRequest[4];
    expect(
      utf8.decode(socksRequest.sublist(5, 5 + length)),
      'destination.invalid',
    );
  });

  test(
    'does not connect directly when the SOCKS5 proxy rejects a request',
    () async {
      final target = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final targetConnected = Completer<void>();
      target.listen((socket) {
        if (!targetConnected.isCompleted) targetConnected.complete();
        socket.destroy();
      });
      addTearDown(target.close);

      final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <Socket>[];
      proxy.listen((socket) {
        sockets.add(socket);
        var greeted = false;
        var rejected = false;
        final bytes = <int>[];
        socket.listen((chunk) {
          bytes.addAll(chunk);
          if (!greeted) {
            if (bytes.length < 2 || bytes.length < 2 + bytes[1]) return;
            bytes.removeRange(0, 2 + bytes[1]);
            greeted = true;
            socket.add([0x05, 0x00]);
          }
          if (!rejected && _completeConnectRequestLength(bytes) != null) {
            rejected = true;
            socket.add([0x05, 0x05, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
            unawaited(socket.close());
          }
        });
      });
      addTearDown(() {
        for (final socket in sockets) {
          socket.destroy();
        }
        return proxy.close();
      });

      final client = const TorHttpClientFactory().create(
        TorProxyEndpoint(host: '127.0.0.1', port: proxy.port),
      );
      addTearDown(() => client.close(force: true));

      await expectLater(
        client
            .getUrl(Uri.parse('http://127.0.0.1:${target.port}/'))
            .timeout(const Duration(seconds: 5)),
        throwsA(anything),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(targetConnected.isCompleted, isFalse);
    },
  );
}

/// TCP packets can split a SOCKS request anywhere, including inside its address.
int? _completeConnectRequestLength(List<int> bytes) {
  if (bytes.length < 4) return null;
  if (bytes[3] == 0x03 && bytes.length < 5) return null;
  final length = switch (bytes[3]) {
    0x01 => 10,
    0x03 => 7 + bytes[4],
    0x04 => 22,
    _ => throw StateError('Unsupported SOCKS address type'),
  };
  return bytes.length >= length ? length : null;
}
