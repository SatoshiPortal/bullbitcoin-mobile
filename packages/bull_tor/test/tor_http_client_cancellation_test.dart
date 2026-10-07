import 'dart:async';
import 'dart:io';

import 'package:bull_tor/tor.dart';
import 'package:test/test.dart';

void main() {
  // Production passes a failure recorder, which wraps the connection task.
  // Both shapes must keep cancellation failures out of the zone.
  for (final withRecorder in [false, true]) {
    final variant = withRecorder ? 'with' : 'without';
    test('closing during SOCKS negotiation does not leak an async error '
        '($variant a failure recorder)', () async {
      final uncaught = <Object>[];
      final finished = Completer<void>();
      runZonedGuarded(() async {
        final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final receivedGreeting = Completer<void>();
        final sockets = <Socket>[];
        final subscription = proxy.listen((socket) {
          sockets.add(socket);
          socket.listen((bytes) {
            if (!receivedGreeting.isCompleted) receivedGreeting.complete();
          });
        });
        final client = const TorHttpClientFactory().create(
          TorProxyEndpoint(host: '127.0.0.1', port: proxy.port),
          failureRecorder: withRecorder ? TorConnectionFailureRecorder() : null,
        );
        try {
          final request = client
              .getUrl(Uri.parse('http://fixture.onion/info'))
              .then<void>((_) {}, onError: (Object _) {});
          await receivedGreeting.future.timeout(const Duration(seconds: 5));
          client.close(force: true);
          for (final socket in sockets) {
            socket.destroy();
          }
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
}
