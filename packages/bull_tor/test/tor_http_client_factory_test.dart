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

  test('closes the proxy socket when HTTPS negotiation fails', () async {
    final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final closed = Completer<void>();
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
            socket.add([0x15, 0x03, 0x03, 0x00, 0x02, 0x02, 0x28]);
            bytes.clear();
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
      throwsA(anything),
    );
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
