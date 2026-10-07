import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bull_tor/tor.dart';
import 'package:socks5_proxy/enums.dart';
import 'package:socks5_proxy/exceptions.dart';
import 'package:test/test.dart';

void main() {
  test(
    'cancelling a task absorbs synchronous socket destruction failures',
    () async {
      final errors = <Object>[];
      final task = cancelSocket(() => throw StateError('already bound'));

      await runZonedGuarded(() => task, (error, _) => errors.add(error));

      expect(errors, isEmpty);
    },
  );

  test(
    'cancelling a task absorbs asynchronous socket destruction failures',
    () async {
      final errors = <Object>[];
      final task = cancelSocket(() async => throw StateError('already bound'));

      await runZonedGuarded(() => task, (error, _) => errors.add(error));

      expect(errors, isEmpty);
    },
  );

  test('cancelling a task releases its socket', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = Completer<Socket>();
    final closed = Completer<void>();
    server.listen((socket) {
      accepted.complete(socket);
      socket.listen((_) {}, onDone: closed.complete);
    });
    addTearDown(server.close);

    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      server.port,
    );
    final remote = await accepted.future;
    final task = ConnectionTask.fromSocket(
      Future.value(socket),
      () => cancelSocket(socket.destroy),
    );

    task.cancel();
    await closed.future.timeout(const Duration(seconds: 1));
    remote.destroy();
  });

  test('sends destination hostnames to SOCKS5 as domain names', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final requestSeen = Completer<List<int>>();
    final httpRequestSeen = Completer<String>();
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
          if (!httpRequestSeen.isCompleted) {
            httpRequestSeen.complete(ascii.decode(bytes));
          }
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
    expect(
      await httpRequestSeen.future.timeout(const Duration(seconds: 5)),
      startsWith('GET / HTTP/1.1\r\n'),
    );
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

  test('closes the proxy socket when HTTPS negotiation fails', () async {
    final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final closed = Completer<void>();
    final clientHelloSeen = Completer<void>();
    proxy.listen((socket) {
      var greeted = false;
      var connected = false;
      final bytes = <int>[];
      socket.listen(
        (chunk) {
          bytes.addAll(chunk);
          if (!greeted && bytes.length >= 3) {
            greeted = true;
            bytes.clear();
            socket.add([0x05, 0x00]);
          } else if (greeted &&
              !connected &&
              bytes.length >= 5 &&
              bytes.length >= 7 + bytes[4]) {
            connected = true;
            socket.add([0x05, 0x00, 0x00, 0x01, 127, 0, 0, 1, 0, 443]);
            bytes.clear();
          } else if (connected &&
              !clientHelloSeen.isCompleted &&
              bytes.length >= 6) {
            expect(bytes[0], 0x16);
            expect(bytes[5], 0x01);
            clientHelloSeen.complete();
            socket.add([0x15, 0x03, 0x03, 0x00, 0x02, 0x02, 0x28]);
          }
        },
        onDone: () {
          if (!closed.isCompleted) closed.complete();
        },
      );
    });
    addTearDown(proxy.close);
    final client = const TorHttpClientFactory().create(
      TorProxyEndpoint(host: '127.0.0.1', port: proxy.port),
    );
    addTearDown(() => client.close(force: true));

    await expectLater(
      client
          .getUrl(Uri.parse('https://destination.invalid/'))
          .timeout(const Duration(seconds: 1)),
      throwsA(isA<HandshakeException>()),
    );
    expect(clientHelloSeen.isCompleted, isTrue);
    await closed.future.timeout(const Duration(seconds: 2));
  });

  test(
    'cancelling pending HTTPS negotiation destroys the raw socket',
    () async {
      final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final proxyClosed = Completer<void>();
      final tunnelConnected = Completer<void>();
      final underlyingReady = Completer<void>();
      proxy.listen((socket) {
        var greeted = false;
        var connected = false;
        final bytes = <int>[];
        socket.listen(
          (chunk) {
            bytes.addAll(chunk);
            if (!greeted && bytes.length >= 3) {
              greeted = true;
              bytes.clear();
              socket.add([0x05, 0x00]);
            } else if (greeted && !connected && bytes.length >= 7) {
              connected = true;
              socket.add([0x05, 0x00, 0x00, 0x01, 127, 0, 0, 1, 0, 443]);
              bytes.clear();
              tunnelConnected.complete();
            }
          },
          onDone: () {
            if (!proxyClosed.isCompleted) proxyClosed.complete();
          },
        );
      });
      addTearDown(proxy.close);
      final task = await const TorHttpClientFactory().createTaskForTesting(
        Uri.parse('https://destination.invalid/'),
        TorProxyEndpoint(host: '127.0.0.1', port: proxy.port),
        onUnderlyingReady: underlyingReady.complete,
      );
      await tunnelConnected.future.timeout(const Duration(seconds: 1));
      await underlyingReady.future.timeout(const Duration(seconds: 1));
      task.cancel();
      await proxyClosed.future.timeout(
        const Duration(seconds: 1),
        onTimeout: () => throw StateError('proxy socket was not closed'),
      );
    },
  );

  // Cancelling while the SOCKS tunnel is still being negotiated must not let
  // the raw socket go on to a TLS handshake once the tunnel opens.
  test('cancelling before the tunnel opens never starts TLS', () async {
    final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(proxy.close);
    final proxyClosed = Completer<void>();
    final connectRequested = Completer<Socket>();
    var tlsBytes = 0;
    proxy.listen((socket) {
      var greeted = false;
      var connected = false;
      final bytes = <int>[];
      socket.listen(
        (chunk) {
          bytes.addAll(chunk);
          if (!greeted && bytes.length >= 3) {
            greeted = true;
            bytes.clear();
            socket.add([0x05, 0x00]);
          } else if (greeted && !connected && bytes.length >= 7) {
            connected = true;
            bytes.clear();
            connectRequested.complete(socket);
          } else if (connected) {
            tlsBytes += chunk.length;
          }
        },
        onDone: () {
          if (!proxyClosed.isCompleted) proxyClosed.complete();
        },
      );
    });

    final task = await const TorHttpClientFactory().createTaskForTesting(
      Uri.parse('https://destination.invalid/'),
      TorProxyEndpoint(host: '127.0.0.1', port: proxy.port),
    );
    task.socket.ignore();
    final tunnel = await connectRequested.future.timeout(
      const Duration(seconds: 1),
    );
    task.cancel();
    tunnel.add([0x05, 0x00, 0x00, 0x01, 127, 0, 0, 1, 0, 443]);

    await proxyClosed.future.timeout(
      const Duration(seconds: 1),
      onTimeout: () => throw StateError('proxy socket was not closed'),
    );
    expect(tlsBytes, 0);
  });

  test('records and rethrows a connection-factory failure', () async {
    final recorder = TorConnectionFailureRecorder();
    final error = const SocksClientConnectionCommandFailedException(
      CommandReplyCode.hostUnreachable,
    );
    final attempt = recorder.begin();

    await expectLater(
      attempt.run(() async {
        recorder.record(error);
        throw error;
      }),
      throwsA(same(error)),
    );
    expect(attempt.take(), SocksConnectionFailureCause.onionServiceUnreachable);
  });

  test('records a failure while awaiting the connection task socket', () async {
    final recorder = TorConnectionFailureRecorder();
    final error = const SocksClientConnectionCommandFailedException(
      CommandReplyCode.connectionRefused,
    );
    final socketFailure = Completer<Socket>();
    final attempt = recorder.begin();
    final socket = expectLater(
      attempt.run(() async {
        recorder.record(error);
        await socketFailure.future;
      }),
      throwsA(same(error)),
    );
    socketFailure.completeError(error);
    await socket;
    expect(attempt.take(), SocksConnectionFailureCause.serviceRefused);
  });

  test('does not attribute a late failure to a concurrent operation', () async {
    final recorder = TorConnectionFailureRecorder();
    final first = recorder.begin();
    final second = recorder.begin();
    final error = const SocksClientConnectionCommandFailedException(
      CommandReplyCode.connectionRefused,
    );
    await expectLater(
      first.run(() async {
        recorder.record(error);
        throw error;
      }),
      throwsA(same(error)),
    );
    expect(second.take(), isNull);
  });

  test('does not attribute a cause observed outside any attempt', () {
    final recorder = TorConnectionFailureRecorder();

    recorder.recordCause(SocksConnectionFailureCause.serviceRefused);

    final attempt = recorder.begin();
    expect(attempt.take(), isNull);
  });

  test('does not consume a late failure through a reused connection', () async {
    final recorder = TorConnectionFailureRecorder();
    final first = recorder.begin();
    final second = recorder.begin();
    final error = const SocksClientConnectionCommandFailedException(
      CommandReplyCode.connectionRefused,
    );

    final lateFailureObserved = Completer<void>();
    await first.run(() async {
      Timer.run(() {
        recorder.record(error);
        lateFailureObserved.complete();
      });
    });
    expect(first.take(), isNull);

    await second.run(() => lateFailureObserved.future);
    expect(first.take(), SocksConnectionFailureCause.serviceRefused);
    expect(second.take(), isNull);
  });
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
