import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bull_tor/tor.dart';
import 'package:test/test.dart';

void main() {
  test('sends destination hostnames to SOCKS5 as domain names', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final requestSeen = Completer<List<int>>();
    var greeted = false;
    server.listen((socket) {
      final bytes = <int>[];
      socket.listen((chunk) {
        bytes.addAll(chunk);
        if (!greeted && bytes.length >= 3) {
          greeted = true;
          socket.add([0x05, 0x00]);
          bytes.clear();
        }
        if (greeted && bytes.length >= 7 && !requestSeen.isCompleted) {
          requestSeen.complete(List<int>.from(bytes));
          socket.add([0x05, 0x00, 0x00, 0x01, 127, 0, 0, 1, 0, 80]);
          socket.add(
            utf8.encode('HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n'),
          );
        }
      });
    });
    addTearDown(server.close);

    final proxiedClient = const TorHttpClientFactory().create(
      TorProxyEndpoint(host: '127.0.0.1', port: server.port),
    );
    addTearDown(() => proxiedClient.close(force: true));

    final request = await proxiedClient
        .getUrl(Uri.parse('http://destination.invalid/'))
        .timeout(const Duration(seconds: 5));
    await request.close();
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
      proxy.listen((socket) {
        var greeted = false;
        final bytes = <int>[];
        socket.listen((chunk) {
          bytes.addAll(chunk);
          if (!greeted && bytes.length >= 3) {
            greeted = true;
            socket.add([0x05, 0x00]);
            bytes.clear();
          } else if (greeted && bytes.length >= 7) {
            socket.add([0x05, 0x05, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
            socket.close();
          }
        });
      });
      addTearDown(proxy.close);

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
