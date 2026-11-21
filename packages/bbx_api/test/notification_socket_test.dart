import 'dart:async';

import 'package:bbx_api/bbx_api.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

import 'fake_socket.dart';

void main() {
  late FakeConnector connector;
  late List<LogRecord> logs;
  late int reads;

  BbxNotificationSocket socket({
    String baseUrl = 'https://api.test',
    Future<String?> Function()? readApiKey,
  }) => BbxNotificationSocket(
    baseUrl: baseUrl,
    readApiKey:
        readApiKey ??
        () async {
          reads++;
          return 'synthetic-key';
        },
    connector: connector.call,
    log: (level, message, {error}) =>
        logs.add(LogRecord(level, message, error)),
  );

  setUp(() {
    connector = FakeConnector(onConnect: (channel) => channel.accept());
    logs = [];
    reads = 0;
  });

  group('webSocketUrl', () {
    for (final (base, url) in [
      ('https://api.test', 'wss://api.test/ak/api-commcenter'),
      ('HTTPS://api.test', 'wss://api.test/ak/api-commcenter'),
      ('http://127.0.0.1:8080', 'ws://127.0.0.1:8080/ak/api-commcenter'),
      (' https://api.test// ', 'wss://api.test/ak/api-commcenter'),
      ('api.test', 'wss://api.test/ak/api-commcenter'),
      ('ws://api.test', 'ws://api.test/ak/api-commcenter'),
      ('wss://api.test/', 'wss://api.test/ak/api-commcenter'),
    ]) {
      test('$base -> $url', () {
        expect(BbxNotificationSocket.webSocketUrl(base), url);
      });
    }
  });

  test('handshake sends the API key header and pings every 30 s', () async {
    final s = socket();
    await s.connect();
    expect(s.isConnected, isTrue);
    expect(connector.handshakes, hasLength(1));
    final handshake = connector.handshakes.single;
    expect(handshake.uri, Uri.parse('wss://api.test/ak/api-commcenter'));
    expect(handshake.headers, {'X-API-Key': 'synthetic-key'});
    expect(handshake.pingInterval, const Duration(seconds: 30));
    expect(logs.map((r) => '$r'), ['fine: WebSocket connected successfully']);
    s.dispose();
  });

  test('connect while connecting or connected does nothing', () async {
    final key = Completer<String?>();
    final s = socket(readApiKey: () => key.future);
    final first = s.connect();
    await s.connect();
    key.complete('k');
    await first;
    await s.connect();
    expect(connector.handshakes, hasLength(1));
    s.dispose();
  });

  test(
    'emits JSON object frames and drops the rest without quoting them',
    () async {
      final s = socket();
      final received = <Map<String, dynamic>>[];
      s.messages.listen(received.add);
      await s.connect();
      final server = connector.handshakes.single.channel.server
        ..add('invalid JSON SYNTHETIC_PRIVATE_FRAME')
        ..add('[]')
        ..add('{"type":{"label":"SYNTHETIC_PRIVATE_FRAME"}}')
        ..add('{"type":"order","orderId":"o1","event":"updated"}')
        ..add({'type': 'balance'});
      await pumpEventQueue();
      expect(received, [
        {
          'type': {'label': 'SYNTHETIC_PRIVATE_FRAME'},
        },
        {'type': 'order', 'orderId': 'o1', 'event': 'updated'},
        {'type': 'balance'},
      ]);
      expect(logs.map((r) => '$r'), [
        'fine: WebSocket connected successfully',
        'warning: WebSocket message rejected: invalid JSON',
        'warning: WebSocket message rejected: invalid shape',
        'info: WebSocket message received',
        'info: WebSocket message received',
        'info: WebSocket message received',
      ]);
      expect(logs.join(), isNot(contains('SYNTHETIC')));
      await server.close();
      s.dispose();
    },
  );

  test('a signed-out user gets no handshake and no retry', () {
    fakeAsync((time) {
      final s = socket(readApiKey: () async => null);
      unawaited(s.connect());
      time.elapse(const Duration(minutes: 1));
      expect(connector.handshakes, isEmpty);
      expect(s.isConnected, isFalse);
      expect(logs.map((r) => '$r'), [
        'fine: WebSocket skipped: user not authenticated',
      ]);
      s.dispose();
    });
  });

  test('key read failures retry every 5 s, warning once, until disposed', () {
    fakeAsync((time) {
      var available = false;
      final s = socket(
        readApiKey: () async {
          reads++;
          if (!available) throw const FormatException('unreadable');
          return null;
        },
      );
      unawaited(s.connect());
      time.flushMicrotasks();
      expect(reads, 1);
      time.elapse(const Duration(seconds: 4));
      expect(reads, 1);
      time.elapse(const Duration(seconds: 1));
      expect(reads, 2);
      available = true;
      time.elapse(const Duration(seconds: 5));
      expect(reads, 3);
      time.elapse(const Duration(seconds: 30));
      expect(reads, 3);
      s.dispose();
      time.flushMicrotasks();
      expect(time.nonPeriodicTimerCount, 0);
      expect(logs.map((r) => '$r'), [
        'warning: WebSocket unavailable FormatException',
        'info: WebSocket retry failed FormatException',
        'fine: WebSocket skipped: user not authenticated',
        'info: WebSocket manually disconnected',
      ]);
    });
  });

  test('a refused handshake closes the channel and retries in 5 s', () {
    fakeAsync((time) {
      connector.onConnect = (channel) =>
          channel.refuse(const SocketLikeException('refused'));
      final s = socket();
      unawaited(s.connect());
      time.flushMicrotasks();
      expect(connector.handshakes, hasLength(1));
      expect(connector.handshakes.single.channel.fakeSink.closes, 1);
      expect(s.isConnected, isFalse);
      time.elapse(const Duration(seconds: 5));
      expect(connector.handshakes, hasLength(2));
      connector.onConnect = (channel) => channel.accept();
      time.elapse(const Duration(seconds: 5));
      expect(connector.handshakes, hasLength(3));
      expect(s.isConnected, isTrue);
      expect(reads, 3);
      s.dispose();
      time.flushMicrotasks();
      expect(time.nonPeriodicTimerCount, 0);
    });
  });

  test('a handshake not upgraded to websocket is not retried', () {
    fakeAsync((time) {
      connector.onConnect = (channel) => channel.refuse(
        const SocketLikeException('Connection was not upgraded to websocket'),
      );
      final s = socket();
      unawaited(s.connect());
      time.elapse(const Duration(minutes: 1));
      expect(connector.handshakes, hasLength(1));
      expect(s.isConnected, isFalse);
      s.dispose();
    });
  });

  test('a closed connection reconnects with a fresh key after 5 s', () {
    fakeAsync((time) {
      final keys = ['first', 'second'];
      final s = socket(readApiKey: () async => keys[reads++]);
      unawaited(s.connect());
      time.flushMicrotasks();
      expect(s.isConnected, isTrue);
      unawaited(connector.handshakes.single.channel.server.close());
      time.flushMicrotasks();
      expect(s.isConnected, isFalse);
      expect(connector.handshakes.single.channel.fakeSink.closes, 1);
      time.elapse(const Duration(seconds: 5));
      expect(s.isConnected, isTrue);
      expect(connector.handshakes.map((h) => h.headers['X-API-Key']), [
        'first',
        'second',
      ]);
      s.dispose();
    });
  });

  test('a stream error reconnects after 5 s', () {
    fakeAsync((time) {
      final s = socket();
      unawaited(s.connect());
      time.flushMicrotasks();
      connector.handshakes.single.channel.server.addError(
        const SocketLikeException('reset'),
      );
      time.flushMicrotasks();
      expect(s.isConnected, isFalse);
      time.elapse(const Duration(seconds: 5));
      expect(connector.handshakes, hasLength(2));
      expect(s.isConnected, isTrue);
      expect(
        logs.map((r) => '$r'),
        contains('warning: WebSocket unavailable SocketLikeException'),
      );
      s.dispose();
    });
  });

  test('disconnect during the key read prevents a late connection', () async {
    final key = Completer<String?>();
    final s = socket(readApiKey: () => key.future);
    final pending = s.connect();
    s.disconnect();
    key.complete('late');
    await pending;
    expect(connector.handshakes, isEmpty);
    expect(s.isConnected, isFalse);
    s.dispose();
  });

  test('disconnect closes the channel and stops reconnecting', () {
    fakeAsync((time) {
      final s = socket();
      unawaited(s.connect());
      time.flushMicrotasks();
      s.disconnect();
      time.flushMicrotasks();
      expect(s.isConnected, isFalse);
      expect(connector.handshakes.single.channel.fakeSink.closes, 1);
      time.elapse(const Duration(minutes: 1));
      expect(connector.handshakes, hasLength(1));
      s.dispose();
    });
  });

  test('reconnect opens a new handshake', () async {
    final s = socket();
    await s.connect();
    await s.reconnect();
    expect(connector.handshakes, hasLength(2));
    expect(connector.handshakes.first.channel.fakeSink.closes, 1);
    expect(s.isConnected, isTrue);
    s.dispose();
  });

  test('an exception closing the sink is logged, not thrown', () async {
    final s = socket();
    await s.connect();
    connector.handshakes.single.channel.fakeSink.closeError =
        const SocketLikeException('close');
    s.disconnect();
    await pumpEventQueue();
    expect(
      logs.map((r) => '$r'),
      contains('info: WebSocket close cleanup failed SocketLikeException'),
    );
    s.dispose();
  });

  test('an Error from the key read disconnects and propagates', () async {
    final s = socket(readApiKey: () async => throw StateError('bug'));
    await expectLater(s.connect(), throwsStateError);
    expect(s.isConnected, isFalse);
    expect(logs.map((r) => '$r'), ['info: WebSocket manually disconnected']);
    s.dispose();
  });

  test(
    'dispose closes the message stream and ignores later connects',
    () async {
      final s = socket();
      final done = s.messages.toList();
      s.dispose();
      await s.connect();
      expect(await done, isEmpty);
      expect(connector.handshakes, isEmpty);
    },
  );
}

class SocketLikeException implements Exception {
  final String message;

  const SocketLikeException(this.message);

  @override
  String toString() => 'SocketLikeException: $message';
}
