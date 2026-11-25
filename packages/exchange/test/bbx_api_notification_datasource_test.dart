import 'dart:async';
import 'dart:io';

import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/bbx_api_notification_datasource.dart';
import 'package:bbx_api/bbx_api.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// The failure of a `Result<void, BbxFailure>`, failing the test on an [Ok].
BbxFailure _failureOfVoid(Result<void, BbxFailure> result) => switch (result) {
  Ok() => fail('Unexpected value'),
  Err(:final failure) => failure,
};

/// A comparable summary of one event, without quoting the frame.
String _summary(Result<BbxNotification, BbxFailure> event) => switch (event) {
  Ok(:final value) => 'ok: ${value.kind.name}/${value.orderId}/${value.event}',
  Err(:final failure) => 'err: $failure',
};

/// Records every log call as text, so a run can be compared.
class _RecordingLogger implements Logger {
  final List<String> calls = [];

  @override
  Object? noSuchMethod(Invocation invocation) {
    calls.add(
      '${invocation.memberName} ${invocation.positionalArguments} '
      '${invocation.namedArguments.values.toList()}',
    );
    return null;
  }
}

class _FakeSink implements WebSocketSink {
  int closes = 0;

  @override
  Future<void> close([int? closeCode, String? closeReason]) async => closes++;

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChannel implements WebSocketChannel {
  final server = StreamController<Object?>();
  final _FakeSink fakeSink = _FakeSink();

  @override
  Stream<Object?> get stream => server.stream;

  @override
  Future<void> get ready => Future.value();

  @override
  WebSocketSink get sink => fakeSink;

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A handshake the server answers with [status] instead of upgrading.
class _RefusingChannel implements WebSocketChannel {
  final int status;
  final _FakeSink fakeSink = _FakeSink();
  final _server = StreamController<Object?>();

  _RefusingChannel(this.status);

  @override
  Stream<Object?> get stream => _server.stream;

  @override
  Future<void> get ready => Future.error(
    WebSocketChannelException.from(
      WebSocketException('Connection was not upgraded to websocket', status),
    ),
  );

  @override
  WebSocketSink get sink => fakeSink;

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Handshake {
  final Uri uri;
  final Map<String, Object> headers;
  final Duration pingInterval;
  final _FakeChannel channel = _FakeChannel();

  _Handshake(this.uri, this.headers, this.pingInterval);
}

BbxApiNotificationDatasource _fakeDatasource({
  required String baseUrl,
  required Future<Result<String?, ExchangeFailure>> Function() readApiKey,
  required BbxWebSocketConnector connector,
  void Function()? onSessionRejected,
}) => BbxApiNotificationDatasource.forTesting(
  baseUrl: baseUrl,
  onSessionRejected: onSessionRejected,
  readApiKey: readApiKey,
  openSocket: (baseUrl, readApiKey, log) => bbxNotificationSocketForTesting(
    baseUrl: baseUrl,
    readApiKey: readApiKey,
    connector: connector,
    log: log,
  ),
);

_RecordingLogger _recordLogs() {
  final previous = log;
  final logger = _RecordingLogger();
  log = logger;
  addTearDown(() => log = previous);
  return logger;
}

void main() {
  late List<_Handshake> handshakes;

  WebSocketChannel connector(
    Uri uri, {
    required Map<String, Object> headers,
    required Duration pingInterval,
  }) {
    final handshake = _Handshake(uri, headers, pingInterval);
    handshakes.add(handshake);
    return handshake.channel;
  }

  setUp(() => handshakes = []);

  group('with a fake socket', () {
    for (final (status, rejected) in [(401, 1), (403, 0)]) {
      test('a handshake refused with $status '
          '${rejected == 1 ? 'reports' : 'does not report'} a rejected '
          'session (INT-7)', () async {
        var reports = 0;
        final datasource = _fakeDatasource(
          baseUrl: 'https://api.bullbitcoin.com',
          readApiKey: () async => const Ok('synthetic-key'),
          connector: (uri, {required headers, required pingInterval}) =>
              _RefusingChannel(status),
          onSessionRejected: () => reports++,
        );
        addTearDown(datasource.dispose);
        expect(
          _failureOfVoid(await datasource.connect()),
          isA<BbxHttpFailure>().having((f) => f.status, 'status', status),
        );
        await pumpEventQueue();
        expect(datasource.isConnected, isFalse);
        expect(reports, rejected);
      });
    }

    for (final (baseUrl, url) in [
      ('https://api.bullbitcoin.com', 'wss://api.bullbitcoin.com'),
      ('https://api05.bullbitcoin.dev', 'wss://api05.bullbitcoin.dev'),
    ]) {
      test('connects to $url/ak/api-commcenter with the active key', () async {
        final datasource = _fakeDatasource(
          baseUrl: baseUrl,
          readApiKey: () async => const Ok('synthetic-key'),
          connector: connector,
        );
        addTearDown(datasource.dispose);
        expect(await datasource.connect(), isA<Ok<void, BbxFailure>>());
        expect(datasource.isConnected, isTrue);
        final handshake = handshakes.single;
        expect(handshake.uri, Uri.parse('$url/ak/api-commcenter'));
        expect(handshake.headers, {'X-API-Key': 'synthetic-key'});
        expect(handshake.pingInterval, const Duration(seconds: 30));
      });
    }

    test(
      'emits owned notifications and a failure per malformed frame',
      () async {
        final datasource = _fakeDatasource(
          baseUrl: 'https://api.bullbitcoin.com',
          readApiKey: () async => const Ok('k'),
          connector: connector,
        );
        addTearDown(datasource.dispose);
        final events = <String>[];
        final listening = datasource.events.listen(
          (e) => events.add(_summary(e)),
        );
        await datasource.connect();
        handshakes.single.channel.server
          ..add('invalid JSON SYNTHETIC_PRIVATE_FRAME')
          ..add('[]')
          ..add('{"type":"order","orderId":"o1","event":"updated"}');
        await pumpEventQueue();
        expect(events, [
          'err: BbxResponseFormatFailure(notification frame)',
          'err: BbxResponseFormatFailure(notification frame)',
          'ok: order/o1/updated',
        ]);
        await listening.cancel();
      },
    );

    test(
      'disconnect during the credential read prevents a connection',
      () async {
        final credential = Completer<Result<String?, ExchangeFailure>>();
        final datasource = _fakeDatasource(
          baseUrl: 'https://api.bullbitcoin.com',
          readApiKey: () => credential.future,
          connector: connector,
        );
        addTearDown(datasource.dispose);
        final pending = datasource.connect();
        datasource.disconnect();
        credential.complete(const Ok('synthetic'));
        expect(await pending, isA<Ok<void, BbxFailure>>());
        expect(handshakes, isEmpty);
        expect(datasource.isConnected, isFalse);
      },
    );

    test('a storage failure is a typed socket failure, never its text', () {
      final logger = _recordLogs();
      fakeAsync((time) {
        var reads = 0;
        final failures = <BbxFailure>[];
        final datasource = _fakeDatasource(
          baseUrl: 'https://example.invalid',
          readApiKey: () async {
            reads++;
            return const Err(ExchangeCredentialReadFailure());
          },
          connector: connector,
        );
        unawaited(
          datasource.connect().then((r) => failures.add(_failureOfVoid(r))),
        );
        time.flushMicrotasks();
        expect(failures.single, isA<BbxCredentialUnavailableFailure>());
        expect(reads, 1);
        expect(handshakes, isEmpty);
        time.elapse(const Duration(seconds: 5));
        expect(reads, 2, reason: 'a storage failure still retries');
        expect(logger.calls.first, contains('BbxCredentialUnavailableFailure'));
        datasource.dispose();
        time.flushMicrotasks();
        expect(
          logger.calls.join(),
          isNot(contains('ExchangeCredentialReadFailure')),
        );
      });
    });

    test('each handshake reads the latest credential', () async {
      String? key = 'first';
      final datasource = _fakeDatasource(
        baseUrl: 'https://api.bullbitcoin.com',
        readApiKey: () async => Ok(key),
        connector: connector,
      );
      addTearDown(datasource.dispose);
      await datasource.connect();
      datasource.disconnect();
      key = 'replacement';
      await datasource.connect();
      datasource.disconnect();
      key = null;
      expect(await datasource.connect(), isA<Ok<void, BbxFailure>>());
      expect(datasource.isConnected, isFalse);
      expect(handshakes.map((h) => h.headers['X-API-Key']), [
        'first',
        'replacement',
      ]);
    });
  });

  test(
    'unreadable keys retry like the old datasource, then logout stops them',
    () {
      final logger = _recordLogs();
      late List<Object> run;
      fakeAsync((time) {
        var reads = 0;
        var available = false;
        Future<Result<String?, ExchangeFailure>> readApiKey() async {
          reads++;
          return available
              ? const Ok(null)
              : const Err(ExchangeCredentialReadFailure());
        }

        final datasource = _fakeDatasource(
          baseUrl: 'https://example.invalid',
          readApiKey: readApiKey,
          connector: connector,
        );
        final readsOverTime = <int>[];
        unawaited(datasource.connect());
        time.flushMicrotasks();
        readsOverTime.add(reads);
        time.elapse(const Duration(seconds: 4));
        readsOverTime.add(reads);
        time.elapse(const Duration(seconds: 1));
        readsOverTime.add(reads);
        available = true;
        // The second failure in a row waits twice as long.
        time.elapse(const Duration(seconds: 10));
        readsOverTime.add(reads);
        time.elapse(const Duration(seconds: 30));
        readsOverTime.add(reads);
        datasource.dispose();
        time.flushMicrotasks();
        expect(time.nonPeriodicTimerCount, 0);
        run = [readsOverTime, logger.calls];
      });
      expect(run[0], [1, 1, 2, 3, 3]);
      expect(run, _expectedRuns['retry']);
      expect(
        (run[1] as List).first,
        contains('BbxCredentialUnavailableFailure'),
      );
      expect(handshakes, isEmpty);
    },
  );

  group('on a local server, as recorded', () {
    Future<List<Object?>> run(
      FutureOr<void> Function(HttpRequest request) handle,
    ) async {
      final logger = _recordLogs();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String>[];
      final sockets = <WebSocket>[];
      final subscription = server.listen((request) async {
        requests.add(
          '${request.method} ${request.uri} '
          '${request.headers.value('X-API-Key')}',
        );
        await handle(request);
      });
      final baseUrl = 'http://127.0.0.1:${server.port}/';
      Future<Result<String?, ExchangeFailure>> readApiKey() async =>
          const Ok('synthetic-header');
      final datasource = BbxApiNotificationDatasource(
        baseUrl: baseUrl,
        readApiKey: readApiKey,
      );
      final events = <String>[];
      final listening = datasource.events.listen(
        (e) => events.add(_summary(e)),
      );
      await datasource.connect();
      final connected = datasource.isConnected;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      datasource.dispose();
      await listening.cancel();
      for (final socket in sockets) {
        await socket.close();
      }
      await subscription.cancel();
      await server.close(force: true);
      return [requests, connected, events, logger.calls];
    }

    test('frames, headers and logs', () async {
      Future<void> handle(HttpRequest request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket
          ..add('invalid JSON SYNTHETIC_PRIVATE_FRAME')
          ..add('[]')
          ..add('{"type":{"label":"SYNTHETIC_PRIVATE_FRAME"}}')
          ..add('{"type":"kyc","event":"approved"}');
        socket.listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await socket.close();
      }

      final bbx = await run(handle);
      expect(bbx[0], ['GET /ak/api-commcenter synthetic-header']);
      expect(bbx[1], isTrue);
      expect(bbx[2], hasLength(4));
      expect(bbx, _expectedRuns['frames']);
      expect((bbx[3] as List).join(), isNot(contains('SYNTHETIC_PRIVATE')));
    });

    test('a refused upgrade', () async {
      Future<void> handle(HttpRequest request) async {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
      }

      final bbx = await run(handle);
      expect(bbx[0], ['GET /ak/api-commcenter synthetic-header']);
      expect(bbx[1], isFalse);
      expect(bbx, _expectedRuns['refused']);
    });
  });
}

/// What the removed ExchangeNotificationDatasource did in the same runs:
/// requests, connection state, events and log calls (or reads over time and log
/// calls). Requests, headers, connection state and the log routes are unchanged;
/// events are now typed results, and a malformed frame maps to the socket's
/// format failure instead of a second, distinct log message.
const _expectedRuns = <String, List<Object?>>{
  'retry': [
    [1, 1, 2, 3, 3],
    [
      'Symbol("warning") [WebSocket unavailable] [BbxCredentialUnavailableFailure, null]',
      'Symbol("info") [WebSocket retry failed] [BbxCredentialUnavailableFailure, null]',
      'Symbol("fine") [WebSocket skipped: user not authenticated] [null, null]',
      'Symbol("info") [WebSocket manually disconnected] [null, null]',
    ],
  ],
  'frames': [
    ['GET /ak/api-commcenter synthetic-header'],
    true,
    [
      'err: BbxResponseFormatFailure(notification frame)',
      'err: BbxResponseFormatFailure(notification frame)',
      'err: BbxResponseFormatFailure(notification frame)',
      'ok: kyc/null/approved',
    ],
    [
      'Symbol("fine") [WebSocket connected successfully] [null, null]',
      'Symbol("warning") [WebSocket message rejected: invalid JSON] [null, null]',
      'Symbol("warning") [WebSocket message rejected: invalid JSON] [null, null]',
      'Symbol("warning") [WebSocket message rejected: invalid JSON] [null, null]',
      'Symbol("info") [WebSocket message received] [null, null]',
      'Symbol("info") [WebSocket manually disconnected] [null, null]',
    ],
  ],
  'refused': [
    ['GET /ak/api-commcenter synthetic-header'],
    false,
    ['err: BbxHttpFailure(status: 403)'],
    [
      'Symbol("warning") [WebSocket unavailable] [BbxHttpFailure, null]',
      'Symbol("info") [WebSocket manually disconnected] [null, null]',
    ],
  ],
};
