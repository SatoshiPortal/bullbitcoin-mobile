import 'dart:async';

import 'package:exchange/src/data/bbx_api_notification_datasource.dart';
import 'package:exchange/src/data/exchange_notification_service.dart';
import 'package:exchange/src/domain/entities/notification_message.dart';
import 'package:exchange/src/domain/exchange_environment.dart';
import 'package:exchange/src/domain/exchange_failure.dart';
import 'package:bbx_api/bbx_api.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _Logger extends Mock implements Logger {}

class _FakeSink implements WebSocketSink {
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChannel implements WebSocketChannel {
  final server = StreamController<Object?>();
  final _sink = _FakeSink();

  @override
  Stream<Object?> get stream => server.stream;

  @override
  Future<void> get ready => Future.value();

  @override
  WebSocketSink get sink => _sink;

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Connector {
  final channels = <_FakeChannel>[];

  WebSocketChannel call(
    Uri uri, {
    required Map<String, Object> headers,
    required Duration pingInterval,
  }) {
    final channel = _FakeChannel();
    channels.add(channel);
    return channel;
  }
}

BbxApiNotificationDatasource _fakeDatasource({
  required String baseUrl,
  required Future<Result<String?, ExchangeFailure>> Function() readApiKey,
  required BbxWebSocketConnector connector,
}) => BbxApiNotificationDatasource.forTesting(
  baseUrl: baseUrl,
  readApiKey: readApiKey,
  openSocket: (baseUrl, readApiKey, log) => bbxNotificationSocketForTesting(
    baseUrl: baseUrl,
    readApiKey: readApiKey,
    connector: connector,
    log: log,
  ),
);

void main() {
  late ExchangeEnvironment currentEnvironment;
  late _Connector mainnetConnector;
  late _Connector testnetConnector;
  late BbxApiNotificationDatasource mainnet;
  late BbxApiNotificationDatasource testnet;
  late Result<String?, ExchangeFailure> mainnetCredential;
  late ExchangeNotificationService service;
  late List<NotificationMessage> messages;
  late StreamSubscription<Result<NotificationMessage, ExchangeFailure>>
  subscription;

  setUp(() {
    currentEnvironment = ExchangeEnvironment.mainnet;
    mainnetConnector = _Connector();
    testnetConnector = _Connector();
    mainnetCredential = const Ok('synthetic');
    mainnet = _fakeDatasource(
      baseUrl: 'https://mainnet.invalid',
      readApiKey: () async => mainnetCredential,
      connector: mainnetConnector.call,
    );
    testnet = _fakeDatasource(
      baseUrl: 'https://testnet.invalid',
      readApiKey: () async => const Ok('synthetic'),
      connector: testnetConnector.call,
    );
    service = ExchangeNotificationService(
      mainnetDatasource: mainnet,
      testnetDatasource: testnet,
      readEnvironment: () async => Ok(currentEnvironment),
    );
    messages = [];
    subscription = service.messageStream.listen((event) {
      if (event case Ok(:final value)) messages.add(value);
    });
  });

  tearDown(() async {
    await subscription.cancel();
    await service.dispose();
  });

  test('forwards the current network only, with its owned fields', () async {
    await service.connect();
    expect(mainnetConnector.channels, hasLength(1));
    expect(testnetConnector.channels, isEmpty);

    mainnetConnector.channels.single.server.add(
      '{"type":"limitOrder","orderId":"o1","event":"updated"}',
    );
    await pumpEventQueue();
    expect(messages, hasLength(1));
    expect(messages.single.kind, NotificationMessageKind.limitOrder);
    expect(messages.single.orderId, 'o1');
    expect(messages.single.event, 'updated');

    // A stale socket of the other environment may still emit; its events are
    // dropped before the app sees them.
    await testnet.connect();
    testnetConnector.channels.single.server.add('{"type":"balance"}');
    await pumpEventQueue();
    expect(messages, hasLength(1));
  });

  test('reconnect follows the environment switch', () async {
    await service.connect();
    currentEnvironment = ExchangeEnvironment.testnet;
    await service.reconnect();
    expect(mainnet.isConnected, isFalse);
    expect(testnet.isConnected, isTrue);
    testnetConnector.channels.single.server.add(
      '{"type":"recipient","event":"VIRTUAL_IBAN_ACTIVATED"}',
    );
    await pumpEventQueue();
    expect(messages.single.kind, NotificationMessageKind.recipient);
    expect(messages.single.event, 'VIRTUAL_IBAN_ACTIVATED');
  });

  test('reports invalid frames and keeps accepting later messages', () async {
    final events = <Object>[];
    final subscription = service.messageStream.listen(events.add);
    addTearDown(subscription.cancel);
    await service.connect();
    mainnetConnector.channels.single.server
      ..add('invalid JSON')
      ..add('{"type":"balance"}');
    await pumpEventQueue();
    expect(events, [
      isA<Err<NotificationMessage, ExchangeFailure>>().having(
        (err) => err.failure,
        'failure',
        isA<ExchangeNotificationsUnavailableFailure>(),
      ),
      isA<Ok<NotificationMessage, ExchangeFailure>>().having(
        (ok) => ok.value.kind,
        'kind',
        NotificationMessageKind.balance,
      ),
    ]);
  });

  test('does not forward the malformed frame or its text', () async {
    final previous = log;
    final logger = _Logger();
    log = logger;
    addTearDown(() => log = previous);
    await service.connect();
    mainnetConnector.channels.single.server
      ..add('invalid JSON SYNTHETIC_PRIVATE_FRAME')
      ..add('{"type":"order"}');
    await pumpEventQueue();

    expect(messages.single.kind, NotificationMessageKind.order);
    verify(
      () => logger.fine(
        'WebSocket notification dropped',
        error: BbxResponseFormatFailure,
      ),
    ).called(1);
    final fine = verify(
      () => logger.fine(captureAny(), error: captureAny(named: 'error')),
    ).captured;
    expect(fine.join(), isNot(contains('SYNTHETIC_PRIVATE_FRAME')));
    expect(messages.single.orderId, isNull, reason: 'no frame field survives');
  });

  test(
    'connection failures stay console-only and keep no credential detail',
    () async {
      final previous = log;
      final logger = _Logger();
      log = logger;
      addTearDown(() => log = previous);
      mainnetCredential = const Err(ExchangeCredentialReadFailure());

      await service.connect();
      await pumpEventQueue();

      expect(messages, isEmpty);
      verify(
        () => logger.info(
          'WebSocket notification dropped',
          error: BbxCredentialUnavailableFailure,
        ),
      ).called(1);
      verifyNever(() => logger.fine(captureAny()));
    },
  );
}
