import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_notification_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/watch_exchange_notifications_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationRepository extends Mock
    implements ExchangeNotificationRepository {}

NotificationMessage _message(String type) =>
    NotificationMessage(type: type, rawData: const {});

void main() {
  late _MockNotificationRepository repository;
  late StreamController<NotificationMessage> messages;

  WatchExchangeNotificationsUsecase build() =>
      WatchExchangeNotificationsUsecase(
        exchangeNotificationRepository: repository,
      );

  setUp(() {
    repository = _MockNotificationRepository();
    messages = StreamController<NotificationMessage>.broadcast();
    when(() => repository.messages).thenAnswer((_) => messages.stream);
  });

  tearDown(() => messages.close());

  test('only account-changing message types are emitted', () async {
    final seen = <String>[];
    final sub = build().accountChanges().listen((m) => seen.add(m.type));
    addTearDown(sub.cancel);

    for (final type in ['balance', 'order', 'group', 'chat', 'kyc', 'promo']) {
      messages.add(_message(type));
    }
    await Future<void>.delayed(Duration.zero);

    expect(seen, [
      'balance',
      'group',
      'kyc',
    ], reason: 'anything else would trigger a needless account refetch');
  });

  // The repository is the boundary; the use-case only lifts the family so no
  // core type reaches the cubit.
  test('a connect failure is lifted into the feature family', () async {
    when(repository.connect).thenAnswer(
      (_) async =>
          const Err(ExchangeNotificationConnectFailure('connect failed: Type')),
    );

    final failure = (await build().connect() as Err).failure as ExchangeFailure;

    expect(failure, isA<ExchangeNotificationsUnavailableFailure>());
    expect(
      failure,
      isNot(isA<ExchangeNotificationFailure>()),
      reason: 'the core family must not escape the use-case',
    );
    expect(failure.logMessage, 'connect failed: Type');
  });

  test('a reconnect failure is lifted into the feature family', () async {
    when(
      repository.reconnect,
    ).thenAnswer((_) async => const Err(ExchangeNotificationConnectFailure()));

    expect(
      (await build().reconnect() as Err).failure,
      isA<ExchangeNotificationsUnavailableFailure>(),
    );
  });

  test('a successful connect is Ok', () async {
    when(repository.connect).thenAnswer((_) async => const Ok(null));

    expect(await build().connect(), isA<Ok<void, ExchangeFailure>>());
  });

  test('disconnect is forwarded', () {
    when(repository.disconnect).thenReturn(null);

    build().disconnect();

    verify(repository.disconnect).called(1);
  });
}
