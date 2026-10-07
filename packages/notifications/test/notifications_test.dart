import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

final class FakeGateway implements LocalNotificationGateway {
  final List<int> shownIds = [];
  bool fail = false;
  Result<bool, NotificationsFailure> permissionResult = const Ok(true);
  int permissionRequestCount = 0;
  NotificationResponseCallback? responseCallback;
  bool invokeLaunch = false;

  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async {
    permissionRequestCount++;
    return permissionResult;
  }

  @override
  Future<Result<void, NotificationsFailure>> initialize(
    NotificationResponseCallback onResponse,
  ) async {
    responseCallback = onResponse;
    return invokeLaunch ? onResponse('launch-payload') : const Ok(null);
  }

  @override
  Future<Result<void, NotificationsFailure>> show(
    LocalNotification notification, {
    required int platformId,
  }) async {
    shownIds.add(platformId);
    return fail ? const Err(NotificationsGatewayFailure()) : const Ok(null);
  }
}

final class FailingResponseOutbox implements NotificationOutboxPort {
  bool fail = true;
  final List<String> responses = [];
  @override
  Future<Result<void, NotificationsFailure>> enqueue(
    LocalNotification event,
  ) async => const Ok(null);
  @override
  Future<Result<NotificationReconcileResult, NotificationsFailure>>
  reconcileTopic(
    String topicId,
    List<LocalNotification> observedEvents,
  ) async => const Ok(NotificationReconcileResult(pendingCount: 0));
  @override
  Future<Result<NotificationReconcileResult, NotificationsFailure>>
  reconcileTopicsAndEnqueue(
    List<NotificationTopicObservation> observations,
    LocalNotification Function(List<LocalNotification> newEvents)
    aggregateEvent,
  ) async => const Ok(NotificationReconcileResult(pendingCount: 0));
  @override
  Future<Result<List<ClaimedNotification>, NotificationsFailure>> claimPending({
    DateTime? now,
  }) async => const Ok([]);
  @override
  Future<Result<void, NotificationsFailure>> markDelivered(
    String eventId,
    String claimToken,
  ) async => const Ok(null);
  @override
  Future<Result<void, NotificationsFailure>> release(
    String eventId,
    String claimToken,
  ) async => const Ok(null);
  @override
  Result<void, NotificationsFailure> persistResponse(String payload) {
    if (fail) return const Err(NotificationsStorageFailure());
    responses.add(payload);
    return const Ok(null);
  }

  @override
  Future<Result<String?, NotificationsFailure>> consumeResponse() async =>
      Ok(responses.isEmpty ? null : responses.removeAt(0));
}

LocalNotification event(String id) => LocalNotification(
  eventId: id,
  title: 'Title',
  body: 'Body',
  destination: NotificationDestination.walletHome,
  createdAt: DateTime.utc(2026, 9, 2),
);

void main() {
  late Directory directory;
  late SqliteNotificationOutbox outbox;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('notifications_test_');
    outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/notifications.sqlite',
    );
  });

  tearDown(() {
    outbox.dispose();
    directory.deleteSync(recursive: true);
  });

  test('enqueue is idempotent for duplicate event IDs', () async {
    expect((await outbox.enqueue(event('same'))), isA<Ok>());
    expect((await outbox.enqueue(event('same'))), isA<Ok>());
    final claimed = await outbox.claimPending();
    expect((claimed as Ok).value, hasLength(1));
  });

  test(
    'first topic reconciliation is silent, later observations create pending events',
    () async {
      final facade = NotificationsFacade(
        gateway: FakeGateway(),
        outbox: outbox,
      );
      final initial = await facade.reconcileTopic('transactions', [
        event('old'),
      ]);
      expect((initial as Ok).value.pendingCount, 0);
      expect((await outbox.claimPending() as Ok).value, isEmpty);

      final later = await facade.reconcileTopic('transactions', [
        event('old'),
        event('new'),
      ]);
      expect((later as Ok).value.pendingCount, 1);
      final pending = (await outbox.claimPending() as Ok).value;
      expect(pending.single.notification.eventId, 'new');
    },
  );

  test('reconciliation is idempotent and pending survives reopen', () async {
    await outbox.reconcileTopic('topic', [event('stable')]);
    final repeated = await outbox.reconcileTopic('topic', [event('stable')]);
    expect((repeated as Ok).value.pendingCount, 0);
    await outbox.reconcileTopic('topic', [event('stable'), event('pending')]);
    outbox.dispose();
    outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/notifications.sqlite',
    );
    final pending = (await outbox.claimPending() as Ok).value;
    expect(pending.single.notification.eventId, 'pending');
  });

  test(
    'atomically reconciles topics and enqueues one aggregate event',
    () async {
      final aggregate = <List<LocalNotification>>[];
      final result = await outbox.reconcileTopicsAndEnqueue(
        [
          NotificationTopicObservation('one', [event('one')]),
          NotificationTopicObservation('two', [event('two')]),
        ],
        (newEvents) {
          aggregate.add(newEvents);
          return event(
            newEvents.map((notification) => notification.eventId).join(','),
          );
        },
      );
      expect(result, isA<Ok>());
      expect(aggregate, isEmpty);
      expect((await outbox.claimPending() as Ok).value, isEmpty);

      final later = await outbox.reconcileTopicsAndEnqueue(
        [
          NotificationTopicObservation('one', [event('one'), event('new-one')]),
          NotificationTopicObservation('two', [event('two'), event('new-two')]),
        ],
        (newEvents) {
          aggregate.add(newEvents);
          return event(
            newEvents.map((notification) => notification.eventId).join(','),
          );
        },
      );
      expect(later, isA<Ok>());
      expect(aggregate.single.map((notification) => notification.eventId), [
        'new-one',
        'new-two',
      ]);
      expect(
        () => aggregate.single.add(event('mutation')),
        throwsUnsupportedError,
      );
      final pending = (await outbox.claimPending() as Ok).value.single;
      expect(pending.notification.eventId, 'new-one,new-two');
      expect(pending.notification.body, 'Body');
      await outbox.reconcileTopicsAndEnqueue([
        NotificationTopicObservation('one', [event('one'), event('new-one')]),
        NotificationTopicObservation('two', [event('two'), event('new-two')]),
      ], (newEvents) => event('aggregate-${newEvents.length}'));
      expect((await outbox.claimPending() as Ok).value, isEmpty);
    },
  );

  test(
    'concurrent topic reconciliation creates no duplicate and probes collisions',
    () async {
      final second = SqliteNotificationOutbox(
        databasePath: '${directory.path}/notifications.sqlite',
      );
      addTearDown(second.dispose);
      final observed = [event('collision-55045'), event('collision-70885')];
      await outbox.reconcileTopic('concurrent', const []);
      final results = await Future.wait([
        outbox.reconcileTopic('concurrent', observed),
        second.reconcileTopic('concurrent', observed.reversed.toList()),
      ]);
      expect(results.whereType<Ok>().length, 2);
      final claims = (await outbox.claimPending() as Ok).value;
      expect(claims, hasLength(2));
      expect(claims.map((claim) => claim.platformId).toSet(), hasLength(2));
    },
  );

  test(
    'two open outboxes cannot claim the same event simultaneously',
    () async {
      final second = SqliteNotificationOutbox(
        databasePath: '${directory.path}/notifications.sqlite',
      );
      addTearDown(second.dispose);
      await outbox.enqueue(event('exclusive'));

      final firstClaim = await outbox.claimPending(
        now: DateTime.utc(2026, 9, 2, 12),
      );
      final secondClaim = await second.claimPending(
        now: DateTime.utc(2026, 9, 2, 12),
      );

      expect((firstClaim as Ok).value, hasLength(1));
      expect((secondClaim as Ok).value, isEmpty);
    },
  );

  test('event IDs map deterministically to 31-bit platform IDs', () {
    final first = NotificationsFacade.hashCandidateFor('first');
    expect(first, inInclusiveRange(0, 0x7fffffff));
    expect(first, NotificationsFacade.hashCandidateFor('first'));
    expect(first, isNot(NotificationsFacade.hashCandidateFor('second')));
  });

  test(
    'permission request delegates success and refusal to the gateway',
    () async {
      final gateway = FakeGateway();
      final facade = NotificationsFacade(gateway: gateway, outbox: outbox);

      expect((await facade.requestPermission() as Ok).value, isTrue);

      gateway.permissionResult = const Ok(false);
      expect((await facade.requestPermission() as Ok).value, isFalse);
    },
  );

  test('permission request delegates gateway failures', () async {
    final gateway = FakeGateway()
      ..permissionResult = const Err(NotificationsGatewayFailure());
    final facade = NotificationsFacade(gateway: gateway, outbox: outbox);

    expect(await facade.requestPermission(), isA<Err>());
  });

  test('initialize does not request permission implicitly', () async {
    final gateway = FakeGateway();
    final facade = NotificationsFacade(gateway: gateway, outbox: outbox);

    expect(await facade.initialize(), isA<Ok>());
    expect(gateway.permissionRequestCount, 0);
  });

  test(
    'colliding hash candidates receive durable distinct platform IDs',
    () async {
      await outbox.enqueue(event('collision-55045'));
      await outbox.enqueue(event('collision-70885'));
      final claims = (await outbox.claimPending() as Ok).value;
      expect(claims.map((claim) => claim.platformId).toSet(), hasLength(2));
      outbox.dispose();
      outbox = SqliteNotificationOutbox(
        databasePath: '${directory.path}/notifications.sqlite',
      );
      final retryClaims =
          (await outbox.claimPending(
                    now: DateTime.now().add(const Duration(minutes: 6)),
                  )
                  as Ok)
              .value;
      expect(
        retryClaims.map((claim) => claim.platformId).toSet(),
        hasLength(2),
      );
    },
  );

  test('obsolete claim tokens are rejected after lease reclaim', () async {
    await outbox.enqueue(event('lease'));
    final first =
        (await outbox.claimPending(now: DateTime.utc(2026, 9, 2, 12)) as Ok)
            .value
            .single;
    final second =
        (await outbox.claimPending(now: DateTime.utc(2026, 9, 2, 12, 6)) as Ok)
            .value
            .single;
    expect(await outbox.markDelivered('lease', first.claimToken), isA<Err>());
    expect(await outbox.markDelivered('lease', second.claimToken), isA<Ok>());
  });

  test(
    'failed response is retained and retried after storage recovers',
    () async {
      final gateway = FakeGateway();
      final responseOutbox = FailingResponseOutbox();
      final facade = NotificationsFacade(
        gateway: gateway,
        outbox: responseOutbox,
      );
      expect(await facade.initialize(), isA<Ok>());
      final payload = NotificationsFacade.encodeDestination(
        NotificationDestination.walletHome,
      );
      expect(gateway.responseCallback!(payload), isA<Err>());
      responseOutbox.fail = false;
      expect(await facade.retryUnpersistedResponses(), isA<Ok>());
      expect(
        (await facade.consumePendingDestination() as Ok).value,
        NotificationDestination.walletHome,
      );
    },
  );

  test('launch persistence failure is returned by initialize', () async {
    final gateway = FakeGateway()..invokeLaunch = true;
    final failing = NotificationsFacade(
      gateway: gateway,
      outbox: FailingResponseOutbox(),
    );
    expect(await failing.initialize(), isA<Err>());
  });

  test(
    'successful delivery marks delivered and retry uses the same ID',
    () async {
      final gateway = FakeGateway();
      final facade = NotificationsFacade(gateway: gateway, outbox: outbox);
      await facade.enqueue(event('retryable'));
      expect(await facade.deliverPending(), isA<Ok>());
      expect(await facade.deliverPending(), isA<Ok>());
      expect(gateway.shownIds, [
        NotificationsFacade.hashCandidateFor('retryable'),
      ]);

      await outbox.enqueue(event('crash-window'));
      final claimed = await outbox.claimPending(
        now: DateTime.utc(2026, 9, 2, 12),
      );
      final recovered = await outbox.claimPending(
        now: DateTime.utc(2026, 9, 2, 12, 6),
      );
      expect((claimed as Ok).value.single.notification.eventId, 'crash-window');
      expect(
        NotificationsFacade.hashCandidateFor(
          (recovered as Ok).value.single.notification.eventId,
        ),
        NotificationsFacade.hashCandidateFor('crash-window'),
      );
    },
  );

  test('gateway failure returns typed failure and remains retryable', () async {
    final gateway = FakeGateway()..fail = true;
    final facade = NotificationsFacade(gateway: gateway, outbox: outbox);
    await facade.enqueue(event('failure'));
    final result = await facade.deliverPending();
    expect(result, isA<Err>());
    gateway.fail = false;
    expect(await facade.deliverPending(), isA<Ok>());
  });

  test('destination payload is stable and rejects unknown values', () {
    final payload = NotificationsFacade.encodeDestination(
      NotificationDestination.walletHome,
    );
    final decoded = NotificationsFacade.decodeDestination(payload);
    expect((decoded as Ok).value, NotificationDestination.walletHome);
    expect(
      NotificationsFacade.decodeDestination('{"destination":"future"}'),
      isA<Err>(),
    );
  });

  test(
    'pending destination is consumed once after reopening the database',
    () async {
      final payload = NotificationsFacade.encodeDestination(
        NotificationDestination.walletHome,
      );
      outbox.persistResponse(payload);
      outbox.dispose();
      outbox = SqliteNotificationOutbox(
        databasePath: '${directory.path}/notifications.sqlite',
      );
      final facade = NotificationsFacade(
        gateway: FakeGateway(),
        outbox: outbox,
      );
      final consumed = await facade.consumePendingDestination();
      expect((consumed as Ok).value, NotificationDestination.walletHome);
      final empty = await facade.consumePendingDestination();
      expect((empty as Ok).value, isNull);
    },
  );
}
