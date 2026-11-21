import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_notification_datasource.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

class _Handshake {
  final Uri uri;
  final Map<String, Object> headers;
  final Duration pingInterval;
  final _FakeChannel channel = _FakeChannel();

  _Handshake(this.uri, this.headers, this.pingInterval);
}

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
    for (final (baseUrl, url) in [
      (ApiServiceConstants.bbApiUrl, 'wss://api.bullbitcoin.com'),
      (ApiServiceConstants.bbApiTestUrl, 'wss://api05.bullbitcoin.dev'),
    ]) {
      test('connects to $url/ak/api-commcenter with the active key', () async {
        final datasource = BbxApiNotificationDatasource(
          baseUrl: baseUrl,
          readApiKey: () async => const Ok('synthetic-key'),
          connector: connector,
        );
        addTearDown(datasource.dispose);
        await datasource.connect();
        expect(datasource.isConnected, isTrue);
        final handshake = handshakes.single;
        expect(handshake.uri, Uri.parse('$url/ak/api-commcenter'));
        expect(handshake.headers, {'X-API-Key': 'synthetic-key'});
        expect(handshake.pingInterval, const Duration(seconds: 30));
      });
    }

    test('emits decoded JSON objects', () async {
      final datasource = BbxApiNotificationDatasource(
        baseUrl: ApiServiceConstants.bbApiUrl,
        readApiKey: () async => const Ok('k'),
        connector: connector,
      );
      addTearDown(datasource.dispose);
      final message = datasource.messageStream.first;
      await datasource.connect();
      handshakes.single.channel.server
        ..add('[]')
        ..add('{"type":"order","orderId":"o1","event":"updated"}');
      expect(await message, {
        'type': 'order',
        'orderId': 'o1',
        'event': 'updated',
      });
    });

    test(
      'disconnect during the credential read prevents a connection',
      () async {
        final credential = Completer<Result<String?, ExchangeApiKeyFailure>>();
        final datasource = BbxApiNotificationDatasource(
          baseUrl: ApiServiceConstants.bbApiUrl,
          readApiKey: () => credential.future,
          connector: connector,
        );
        addTearDown(datasource.dispose);
        final pending = datasource.connect();
        datasource.disconnect();
        credential.complete(const Ok('synthetic'));
        await pending;
        expect(handshakes, isEmpty);
        expect(datasource.isConnected, isFalse);
      },
    );

    test('each handshake reads the latest credential', () async {
      String? key = 'first';
      final datasource = BbxApiNotificationDatasource(
        baseUrl: ApiServiceConstants.bbApiUrl,
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
      await datasource.connect();
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
        Future<Result<String?, ExchangeApiKeyFailure>> readApiKey() async {
          reads++;
          return available
              ? const Ok(null)
              : const Err(ExchangeApiKeyReadFailure());
        }

        final datasource = BbxApiNotificationDatasource(
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
        time.elapse(const Duration(seconds: 5));
        readsOverTime.add(reads);
        time.elapse(const Duration(seconds: 30));
        readsOverTime.add(reads);
        datasource.dispose();
        time.flushMicrotasks();
        expect(time.nonPeriodicTimerCount, 0);
        run = [readsOverTime, logger.calls];
      });
      expect(run[0], [1, 1, 2, 3, 3]);
      expect(run, _oldRuns['retry']);
      expect(
        (run[1] as List).first,
        contains('$ExchangeAuthenticationException'),
      );
      expect(handshakes, isEmpty);
    },
  );

  group('matches the old datasource on a local server, as recorded', () {
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
      Future<Result<String?, ExchangeApiKeyFailure>> readApiKey() async =>
          const Ok('synthetic-header');
      final datasource = BbxApiNotificationDatasource(
        baseUrl: baseUrl,
        readApiKey: readApiKey,
      );
      final messages = <Map<String, dynamic>>[];
      final listening = datasource.messageStream.listen(messages.add);
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
      return [requests, connected, messages, logger.calls];
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
      expect(bbx[2], hasLength(2));
      expect(bbx, _oldRuns['frames']);
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
      expect(bbx, _oldRuns['refused']);
    });
  });
}

/// What the removed ExchangeNotificationDatasource did in the same runs:
/// requests, connection state, messages and log calls (or reads over time
/// and log calls).
const _oldRuns = <String, List<Object?>>{
  'retry': [
    [1, 1, 2, 3, 3],
    [
      'Symbol("warning") [WebSocket unavailable] [ExchangeAuthenticationException, null]',
      'Symbol("info") [WebSocket retry failed] [ExchangeAuthenticationException, null]',
      'Symbol("fine") [WebSocket skipped: user not authenticated] [null, null]',
      'Symbol("info") [WebSocket manually disconnected] [null, null]',
    ],
  ],
  'frames': [
    ['GET /ak/api-commcenter synthetic-header'],
    true,
    [
      {
        'type': {'label': 'SYNTHETIC_PRIVATE_FRAME'},
      },
      {'type': 'kyc', 'event': 'approved'},
    ],
    [
      'Symbol("fine") [WebSocket connected successfully] [null, null]',
      'Symbol("warning") [WebSocket message rejected: invalid JSON] [null, null]',
      'Symbol("warning") [WebSocket message rejected: invalid shape] [null, null]',
      'Symbol("info") [WebSocket message received] [null, null]',
      'Symbol("info") [WebSocket message received] [null, null]',
      'Symbol("info") [WebSocket manually disconnected] [null, null]',
    ],
  ],
  'refused': [
    ['GET /ak/api-commcenter synthetic-header'],
    false,
    [],
    [
      'Symbol("warning") [WebSocket unavailable] [WebSocketChannelException, null]',
      'Symbol("info") [WebSocket manually disconnected] [null, null]',
    ],
  ],
};
