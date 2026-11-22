import 'dart:async';

import 'package:bbx_api/bbx_api.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:fake_async/fake_async.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'fake_socket.dart';

/// The failure of a `Result<void, BbxFailure>`, failing the test on an [Ok].
BbxFailure failureOfVoid(Result<void, BbxFailure> result) => switch (result) {
  Ok() => fail('Unexpected value'),
  Err(:final failure) => failure,
};

/// A comparable summary of one event, without quoting the frame.
String summary(Result<BbxNotification, BbxFailure> event) => switch (event) {
  Ok(:final value) => 'ok: ${value.kind.name}/${value.orderId}/${value.event}',
  Err(:final failure) => 'err: $failure',
};

void main() {
  late FakeConnector connector;
  late List<LogRecord> logs;
  late int reads;

  BbxNotificationSocket socket({
    String baseUrl = 'https://api.test',
    Future<Result<String?, BbxFailure>> Function()? readApiKey,
  }) => bbxNotificationSocketForTesting(
    baseUrl: baseUrl,
    readApiKey:
        readApiKey ??
        () async {
          reads++;
          return const Ok('synthetic-key');
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
    expect(await s.connect(), isA<Ok<void, BbxFailure>>());
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
    final key = Completer<Result<String?, BbxFailure>>();
    final s = socket(readApiKey: () => key.future);
    final first = s.connect();
    expect(await s.connect(), isA<Ok<void, BbxFailure>>());
    key.complete(const Ok('k'));
    await first;
    await s.connect();
    expect(connector.handshakes, hasLength(1));
    s.dispose();
  });

  test('emits typed notifications and a failure per malformed frame', () async {
    final s = socket();
    final received = <Result<BbxNotification, BbxFailure>>[];
    s.events.listen(received.add);
    await s.connect();
    final server = connector.handshakes.single.channel.server
      ..add('invalid JSON SYNTHETIC_PRIVATE_FRAME')
      ..add('[]')
      ..add('{"type":{"label":"SYNTHETIC_PRIVATE_FRAME"}}')
      ..add('{"orderId":7}')
      ..add('{"type":"order","orderId":"o1","event":"updated"}')
      ..add({'type': 'balance'});
    await pumpEventQueue();
    expect(received.map(summary), [
      'err: BbxResponseFormatFailure(notification frame)',
      'err: BbxResponseFormatFailure(notification frame)',
      'err: BbxResponseFormatFailure(notification frame)',
      'err: BbxResponseFormatFailure(notification frame)',
      'ok: order/o1/updated',
      'ok: balance/null/null',
    ]);
    expect(logs.map((r) => '$r'), [
      'fine: WebSocket connected successfully',
      'warning: WebSocket message rejected: invalid JSON',
      'warning: WebSocket message rejected: invalid JSON',
      'warning: WebSocket message rejected: invalid JSON',
      'warning: WebSocket message rejected: invalid JSON',
      'info: WebSocket message received',
      'info: WebSocket message received',
    ]);
    expect(logs.join(), isNot(contains('SYNTHETIC')));
    expect(logs.join(), isNot(contains('o1')));
    await server.close();
    s.dispose();
  });

  test('maps every known type and keeps an unknown one', () async {
    final s = socket();
    final kinds = <BbxNotificationKind>[];
    s.events.listen(
      (event) => event.fold((n) => kinds.add(n.kind), (f) => fail('$f')),
    );
    await s.connect();
    connector.handshakes.single.channel.server
      ..add('{"type":"balance"}')
      ..add('{"type":"group"}')
      ..add('{"type":"kyc"}')
      ..add('{"type":"userPreferences"}')
      ..add('{"type":"message"}')
      ..add('{"type":"order"}')
      ..add('{"type":"limitOrder"}')
      ..add('{"type":"user"}')
      ..add('{"type":"recipient"}')
      ..add('{"type":"never-seen"}')
      ..add('{}');
    await pumpEventQueue();
    expect(kinds, [
      ...BbxNotificationKind.values,
      BbxNotificationKind.unknown,
    ], reason: 'a missing type and an unknown one are both unknown');
    s.dispose();
  });

  test('a signed-out user is silent: no event, no handshake, no retry', () {
    fakeAsync((time) {
      var keyReads = 0;
      final s = socket(
        readApiKey: () async {
          keyReads++;
          return const Ok(null);
        },
      );
      final events = <Result<BbxNotification, BbxFailure>>[];
      s.events.listen(events.add);
      final results = <Result<void, BbxFailure>>[];
      unawaited(s.connect().then(results.add));
      time.flushMicrotasks();
      expect(results.single, isA<Ok<void, BbxFailure>>());
      expect(s.isConnected, isFalse);
      expect(
        time.nonPeriodicTimerCount,
        0,
        reason: 'a signed-out skip schedules no retry timer',
      );
      // Far past the 5 s retry delay and the 30 s ping interval.
      time.elapse(const Duration(minutes: 5));
      expect(keyReads, 1, reason: 'the credential is never re-read');
      expect(connector.handshakes, isEmpty);
      expect(events, isEmpty);
      expect(logs.map((r) => '$r'), [
        'fine: WebSocket skipped: user not authenticated',
      ]);
      s.dispose();
      time.flushMicrotasks();
      expect(time.nonPeriodicTimerCount, 0);
    });
  });

  test('a signed-out skip does not stop a later signed-in connect', () {
    fakeAsync((time) {
      String? key;
      final s = socket(
        readApiKey: () async {
          reads++;
          return Ok(key);
        },
      );
      unawaited(s.connect());
      time.flushMicrotasks();
      expect(connector.handshakes, isEmpty);
      key = 'late-key';
      unawaited(s.connect());
      time.flushMicrotasks();
      expect(reads, 2, reason: 'each connect reads the credential again');
      expect(connector.handshakes.single.headers['X-API-Key'], 'late-key');
      expect(s.isConnected, isTrue);
      s.dispose();
      time.flushMicrotasks();
      expect(time.nonPeriodicTimerCount, 0);
    });
  });

  test('key read failures retry every 5 s, warning once, until disposed', () {
    fakeAsync((time) {
      var available = false;
      final s = socket(
        readApiKey: () async {
          reads++;
          if (!available) return const Err(BbxCredentialUnavailableFailure());
          return const Ok(null);
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
        'warning: WebSocket unavailable BbxCredentialUnavailableFailure',
        'info: WebSocket retry failed BbxCredentialUnavailableFailure',
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
      final events = <Result<BbxNotification, BbxFailure>>[];
      final results = <Result<void, BbxFailure>>[];
      s.events.listen(events.add);
      unawaited(s.connect().then(results.add));
      time.flushMicrotasks();
      expect(failureOfVoid(results.single), isA<BbxConnectionFailure>());
      expect(connector.handshakes, hasLength(1));
      expect(connector.handshakes.single.channel.fakeSink.closes, 1);
      expect(s.isConnected, isFalse);
      expect(events, hasLength(1), reason: 'one event per failed attempt');
      expect(switch (events.single) {
        Err(:final failure) => failure,
        Ok() => fail('Unexpected value'),
      }, isA<BbxConnectionFailure>());
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

  test('a failed connect returns its failure', () {
    fakeAsync((time) {
      connector.onConnect = (channel) => channel.readyCompleter.complete(
        Future.error(const SocketLikeException('refused')),
      );
      final s = socket();
      final results = <Result<void, BbxFailure>>[];
      unawaited(s.connect().then(results.add));
      time.flushMicrotasks();
      expect(failureOfVoid(results.single), isA<BbxConnectionFailure>());
      expect(s.isConnected, isFalse);
      expect(connector.handshakes.single.channel.fakeSink.closes, 1);
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
      final keys = [
        const Ok<String?, BbxFailure>('first'),
        const Ok<String?, BbxFailure>('second'),
      ];
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
        contains('warning: WebSocket unavailable BbxConnectionFailure'),
      );
      s.dispose();
    });
  });

  test('disconnect during the key read prevents a late connection', () async {
    final key = Completer<Result<String?, BbxFailure>>();
    final s = socket(readApiKey: () => key.future);
    final pending = s.connect();
    s.disconnect();
    key.complete(const Ok('late'));
    expect(await pending, isA<Ok<void, BbxFailure>>());
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
    expect(await s.reconnect(), isA<Ok<void, BbxFailure>>());
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

  test('dispose closes the event stream and ignores later connects', () async {
    final s = socket();
    final done = s.events.toList();
    s.dispose();
    expect(await s.connect(), isA<Ok<void, BbxFailure>>());
    expect(await done, isEmpty);
    expect(connector.handshakes, isEmpty);
  });
}

class SocketLikeException implements Exception {
  final String message;

  const SocketLikeException(this.message);

  @override
  String toString() => 'SocketLikeException: $message';
}
