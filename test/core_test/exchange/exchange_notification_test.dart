import 'dart:async';

import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/data/services/exchange_notification_service.dart';
import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSocket extends Mock implements bbx.NotificationSocketService {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _FakeDatasource implements ExchangeNotificationDatasource {
  final messages = StreamController<bbx.NotificationMessage>.broadcast();

  @override
  Stream<bbx.NotificationMessage> get messageStream => messages.stream;

  @override
  bool get isConnected => false;

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}

  @override
  Future<void> reconnect() async {}

  @override
  void dispose() => messages.close();
}

void main() {
  group('BbxApiNotificationDatasource', () {
    late _MockSocket socket;
    late BbxApiNotificationDatasource datasource;

    setUp(() {
      socket = _MockSocket();
      datasource = BbxApiNotificationDatasource(socket);
    });

    test('reconnects through the socket service', () async {
      when(
        () => socket.reconnect(),
      ).thenAnswer((_) async => const bbx.ApiResult<void>.success(data: null));

      await datasource.reconnect();

      verify(() => socket.reconnect()).called(1);
      verifyNever(() => socket.disconnect());
    });

    test('streams the typed socket messages', () async {
      final message = bbx.NotificationMessage.fromJson({'type': 'balance'});
      when(() => socket.notifications).thenAnswer((_) => Stream.value(message));

      expect(await datasource.messageStream.single, same(message));
    });
  });

  group('ExchangeNotificationService', () {
    late _FakeDatasource mainnet;
    late ExchangeNotificationService service;

    setUp(() {
      mainnet = _FakeDatasource();
      service = ExchangeNotificationService(
        mainnetDatasource: mainnet,
        testnetDatasource: _FakeDatasource(),
        settingsRepository: _MockSettingsRepository(),
      );
      addTearDown(service.dispose);
    });

    Future<NotificationMessage> deliver(Map<String, dynamic> json) async {
      final next = service.messageStream.first;
      mainnet.messages.add(bbx.NotificationMessage.fromJson(json));
      return next;
    }

    test('an order message keeps its order id', () async {
      final message = await deliver({'type': 'order', 'orderId': 'o-1'});

      expect(message.kind, NotificationMessageKind.order);
      expect(message.orderId, 'o-1');
    });

    test('a recipient message keeps its event', () async {
      final message = await deliver({
        'type': 'recipient',
        'recipientId': 'r-1',
        'event': 'payee.activated',
      });

      expect(message.kind, NotificationMessageKind.recipient);
      expect(message.event, 'payee.activated');
    });

    test('a type the app does not handle is unknown', () async {
      final message = await deliver({'type': 'announcement'});

      expect(message.kind, NotificationMessageKind.unknown);
    });
  });
}
