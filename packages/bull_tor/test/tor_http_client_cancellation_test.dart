import 'dart:async';
import 'dart:io';

import 'package:bull_tor/tor.dart';
import 'package:test/test.dart';

void main() {
  // Production passes a failure recorder, which wraps the connection task.
  // Both shapes must keep cancellation failures out of the zone.
  for (final (withRecorder, scheme) in [
    (false, 'http'),
    (true, 'http'),
    (false, 'https'),
    (true, 'https'),
  ]) {
    final variant = withRecorder ? 'with' : 'without';
    test('closing during SOCKS negotiation does not leak an async error '
        '($scheme, $variant a failure recorder)', () async {
      final uncaught = <Object>[];
      final finished = Completer<void>();
      runZonedGuarded(() async {
        final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final receivedGreeting = Completer<void>();
        final peerClosed = Completer<void>();
        final sockets = <Socket>[];
        final subscription = proxy.listen((socket) {
          sockets.add(socket);
          socket.listen(
            (bytes) {
              if (!receivedGreeting.isCompleted) receivedGreeting.complete();
            },
            onDone: () {
              if (!peerClosed.isCompleted) peerClosed.complete();
            },
          );
        });
        final client = const TorHttpClientFactory().create(
          TorProxyEndpoint(host: '127.0.0.1', port: proxy.port),
          failureRecorder: withRecorder ? TorConnectionFailureRecorder() : null,
        );
        try {
          final request = client
              .getUrl(Uri.parse('$scheme://fixture.onion/info'))
              .then<void>((_) {}, onError: (Object _) {});
          await receivedGreeting.future.timeout(const Duration(seconds: 5));
          client.close(force: true);
          // Observe EOF before teardown: a silent proxy must not be needed
          // to close a connection the HTTP client has already cancelled.
          await peerClosed.future.timeout(const Duration(milliseconds: 500));
          await request.timeout(const Duration(seconds: 5));
          // Drain callbacks from both the request and its cancellation task.
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
        } finally {
          client.close(force: true);
          for (final socket in sockets) {
            socket.destroy();
          }
          await subscription.cancel();
          await proxy.close();
          finished.complete();
        }
      }, (error, stack) => uncaught.add(error));
      await finished.future.timeout(const Duration(seconds: 10));
      expect(uncaught, isEmpty);
    });
  }

  for (final scheme in ['http', 'https']) {
    test(
      'cancellation closes a silent CONNECT reply socket ($scheme)',
      () async {
        final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final connectSeen = Completer<void>();
        final peerClosed = Completer<void>();
        final sockets = <Socket>[];
        final subscription = proxy.listen((socket) {
          sockets.add(socket);
          var greeted = false;
          final bytes = <int>[];
          socket.listen(
            (chunk) {
              bytes.addAll(chunk);
              if (!greeted && bytes.length >= 3) {
                greeted = true;
                bytes.removeRange(0, 3);
                socket.add([0x05, 0x00]);
              }
              if (greeted && bytes.length >= 7 && !connectSeen.isCompleted) {
                connectSeen.complete();
              }
            },
            onDone: () {
              if (!peerClosed.isCompleted) peerClosed.complete();
            },
          );
        });
        final client = const TorHttpClientFactory().create(
          TorProxyEndpoint(host: '127.0.0.1', port: proxy.port),
          failureRecorder: TorConnectionFailureRecorder(),
        );
        try {
          final request = client
              .getUrl(Uri.parse('$scheme://fixture.onion/info'))
              .then<void>((_) {}, onError: (Object _) {});
          await connectSeen.future.timeout(const Duration(seconds: 5));
          client.close(force: true);
          await peerClosed.future.timeout(const Duration(seconds: 1));
          await request.timeout(const Duration(seconds: 5));
        } finally {
          client.close(force: true);
          for (final socket in sockets) {
            socket.destroy();
          }
          await subscription.cancel();
          await proxy.close();
        }
      },
    );
  }

  test(
    'cancellation before the TCP dial handle arrives cancels that dial',
    () async {
      final dial = Completer<ConnectionTask<Socket>>();
      final socket = Completer<Socket>();
      var cancelled = false;
      final task = await IOOverrides.runZoned(
        () => const TorHttpClientFactory().createTaskForTesting(
          Uri.parse('http://fixture.onion/info'),
          TorProxyEndpoint(host: '127.0.0.1', port: 9050),
        ),
        socketStartConnect: (host, port, {sourceAddress, sourcePort = 0}) =>
            dial.future,
      );
      final failed = expectLater(task.socket, throwsA(isA<SocketException>()));
      task.cancel();
      dial.complete(
        ConnectionTask.fromSocket(socket.future, () {
          cancelled = true;
          socket.completeError(const SocketException('Cancelled fixture dial'));
        }),
      );
      await failed;
      expect(cancelled, isTrue);
    },
  );
}
