import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _Keys extends Mock implements BullbitcoinApiKeyDatasource {}

class _Channel extends Mock implements WebSocketChannel {}

class _Sink extends Mock implements WebSocketSink {}

class _Logger extends Mock implements Logger {}

void main() {
  setUpAll(() => registerFallbackValue(StackTrace.empty));
  late _Keys keys;
  late _Logger logger;
  late Logger previousLogger;
  late List<Completer<void>> ready;
  late List<StreamController<dynamic>> streams;
  late ExchangeNotificationDatasource datasource;
  late bool foreground;

  setUp(() {
    previousLogger = log;
    logger = _Logger();
    log = logger;
    keys = _Keys();
    when(() => keys.get(isTestnet: false)).thenAnswer(
      (_) async => ExchangeApiKeyModel(
        id: 'test',
        key: 'test-only',
        name: 'test',
        userId: 'test',
        isActive: true,
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    foreground = true;
    ready = [];
    streams = [];
    datasource = ExchangeNotificationDatasource(
      baseUrl: 'https://example.test',
      apiKeyDatasource: keys,
      isTestnet: false,
      isForeground: () => foreground,
      openChannel: (uri, headers) {
        final channel = _Channel();
        final sink = _Sink();
        final completion = Completer<void>();
        final stream = StreamController<dynamic>();
        ready.add(completion);
        streams.add(stream);
        when(() => channel.ready).thenAnswer((_) => completion.future);
        when(() => channel.stream).thenAnswer((_) => stream.stream);
        when(() => channel.sink).thenReturn(sink);
        when(() => sink.close()).thenAnswer((_) async {});
        return channel;
      },
    );
  });
  tearDown(() async {
    datasource.dispose();
    for (final stream in streams) {
      // Mock channels have no native socket to close.
      unawaited(stream.close());
    }
    log = previousLogger;
  });

  test(
    'disconnect during handshake does not log a null assertion failure',
    () async {
      final connecting = datasource.connect();
      await Future<void>.delayed(Duration.zero);
      datasource.disconnect();
      ready.single.complete();
      await connecting;
      expect(datasource.isConnected, isFalse);
      verifyNever(
        () => logger.severe(
          message: any(named: 'message'),
          error: any(named: 'error'),
          trace: any(named: 'trace'),
        ),
      );
    },
  );

  test(
    'disconnect while reading credentials prevents opening a socket',
    () async {
      final key = Completer<ExchangeApiKeyModel?>();
      when(() => keys.get(isTestnet: false)).thenAnswer((_) => key.future);
      final connecting = datasource.connect();
      datasource.disconnect();
      key.complete(
        ExchangeApiKeyModel(
          id: 'test',
          key: 'test-only',
          name: 'test',
          userId: 'test',
          isActive: true,
          createdAt: 0,
          updatedAt: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      if (ready.isNotEmpty) ready.single.complete();
      await connecting;
      expect(ready, isEmpty);
    },
  );

  test('a failed old handshake cannot disconnect a replacement', () async {
    final first = datasource.connect();
    await Future<void>.delayed(Duration.zero);
    datasource.disconnect();
    final second = datasource.connect();
    await Future<void>.delayed(Duration.zero);
    ready[1].complete();
    await second;
    ready[0].completeError(const SocketException('offline'));
    await first;
    expect(datasource.isConnected, isTrue);
  });

  test(
    'a programmer error releases the connection attempt and propagates',
    () async {
      final first = datasource.connect();
      await Future<void>.delayed(Duration.zero);
      final failure = expectLater(first, throwsStateError);
      ready.single.completeError(StateError('broken handshake'));
      await failure;

      final replacement = datasource.connect();
      await Future<void>.delayed(Duration.zero);
      expect(ready, hasLength(2));
      ready.last.complete();
      await replacement;
      expect(datasource.isConnected, isTrue);
    },
  );

  test('a stale programmer error cannot close a replacement', () async {
    final first = datasource.connect();
    await Future<void>.delayed(Duration.zero);
    datasource.disconnect();
    final replacement = datasource.connect();
    await Future<void>.delayed(Duration.zero);
    ready[1].complete();
    await replacement;

    final failure = expectLater(first, throwsStateError);
    ready[0].completeError(StateError('obsolete handshake'));
    await failure;
    expect(datasource.isConnected, isTrue);
  });

  test('DNS retries back off and stop after disposal', () {
    fakeAsync((time) {
      unawaited(datasource.connect());
      time.flushMicrotasks();
      ready[0].completeError(const SocketException('offline'));
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 5));
      expect(ready, hasLength(2));
      ready[1].completeError(const SocketException('offline'));
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 5));
      expect(ready, hasLength(2));
      time.elapse(const Duration(seconds: 5));
      expect(ready, hasLength(3));
      ready[2].completeError(const SocketException('offline'));
      time.flushMicrotasks();
      datasource.dispose();
      time.elapse(const Duration(minutes: 5));
      expect(ready, hasLength(3));
    });
  });
  test('no authentication or DNS work starts outside foreground', () async {
    foreground = false;
    await datasource.connect();
    expect(ready, isEmpty);
    verifyNever(() => keys.get(isTestnet: false));
  });

  test('leaving foreground during handshake discards the connection', () async {
    final connecting = datasource.connect();
    await Future<void>.delayed(Duration.zero);
    foreground = false;
    ready.single.complete();
    await connecting;
    expect(datasource.isConnected, isFalse);
  });

  test('stream error and close schedule only one reconnect', () {
    fakeAsync((time) {
      unawaited(datasource.connect());
      time.flushMicrotasks();
      ready.single.complete();
      time.flushMicrotasks();
      streams.single.addError(const SocketException('offline'));
      unawaited(streams.single.close());
      time.flushMicrotasks();
      expect(time.pendingTimers, hasLength(1));
      time.elapse(const Duration(seconds: 5));
      expect(ready, hasLength(2));
      ready.last.complete();
      time.flushMicrotasks();
      expect(datasource.isConnected, isTrue);
    });
  });

  test('a pending retry does not open a socket in background', () {
    fakeAsync((time) {
      unawaited(datasource.connect());
      time.flushMicrotasks();
      ready.single.completeError(const SocketException('offline'));
      time.flushMicrotasks();
      foreground = false;
      time.elapse(const Duration(minutes: 2));
      expect(ready, hasLength(1));
      expect(time.pendingTimers, isEmpty);
    });
  });

  test('retry delay is capped at one minute', () {
    fakeAsync((time) {
      unawaited(datasource.connect());
      time.flushMicrotasks();
      var attempts = 1;
      for (final seconds in [5, 10, 20, 40, 60, 60]) {
        ready.last.completeError(const SocketException('offline'));
        time.flushMicrotasks();
        time.elapse(Duration(seconds: seconds - 1));
        expect(ready, hasLength(attempts));
        time.elapse(const Duration(seconds: 1));
        expect(ready, hasLength(++attempts));
      }
      ready.last.complete();
      time.flushMicrotasks();
      datasource.dispose();
    });
  });

  test('disconnect cancels an explicit delayed reconnect', () {
    fakeAsync((time) {
      unawaited(datasource.reconnect());
      datasource.disconnect();
      time.elapse(const Duration(seconds: 2));
      expect(ready, isEmpty);
    });
  });

  test('explicit disconnect starts a fresh retry round', () {
    fakeAsync((time) {
      unawaited(datasource.connect());
      time.flushMicrotasks();
      for (final seconds in [5, 10, 20, 40]) {
        ready.last.completeError(const SocketException('offline'));
        time.flushMicrotasks();
        time.elapse(Duration(seconds: seconds));
      }
      ready.last.completeError(const SocketException('offline'));
      time.flushMicrotasks();
      datasource.disconnect();
      time.elapse(const Duration(minutes: 2));
      expect(ready, hasLength(5));

      unawaited(datasource.connect());
      time.flushMicrotasks();
      ready.last.completeError(const SocketException('offline'));
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 4));
      expect(ready, hasLength(6));
      time.elapse(const Duration(seconds: 1));
      expect(ready, hasLength(7));
      ready.last.complete();
      time.flushMicrotasks();
    });
  });

  test('a disposed datasource cannot reconnect', () async {
    datasource.dispose();
    await datasource.connect();
    await datasource.reconnect();
    expect(ready, isEmpty);
  });
}
