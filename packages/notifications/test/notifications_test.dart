import 'dart:io';
import 'package:bull_logger/bull_logger.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

final class FakeGateway implements LocalNotificationGateway {
  final List<int> shownIds = [];
  bool fail = false;
  bool enabled = true;
  Result<bool, NotificationsFailure> permissionResult = const Ok(true);
  int permissionRequestCount = 0;
  int settingsOpenCount = 0;

  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async {
    permissionRequestCount++;
    return permissionResult;
  }

  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async => Ok(enabled);

  @override
  Future<Result<void, NotificationsFailure>> openSystemSettings() async {
    settingsOpenCount++;
    return const Ok(null);
  }

  @override
  Future<Result<void, NotificationsFailure>> initialize() async =>
      const Ok(null);

  @override
  Future<Result<void, NotificationsFailure>> show(
    LocalNotification notification, {
    required int platformId,
  }) async {
    shownIds.add(platformId);
    return fail ? const Err(NotificationsGatewayFailure()) : const Ok(null);
  }
}

LocalNotification aggregate(List<String> ids) => LocalNotification(
  eventId: 'aggregate-${ids.join(',')}',
  title: 'Title',
  body: 'Body',
  createdAt: DateTime.utc(2026, 9, 2),
);

Future<void> pending(NotificationStoreRepository outbox, String id) async {
  expect(await outbox.recordForeground(Observation('delivery', [])), isA<Ok>());
  expect(
    await outbox.recordBackground(Observation('delivery', [id]), aggregate),
    isA<Ok>(),
  );
}

void main() {
  late Directory directory;
  late SqliteNotificationStoreRepository outbox;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('notifications_test_');
    log = Logger.replace(directory: directory);
    outbox =
        (SqliteNotificationStoreRepository.openForeground(
                  '${directory.path}/notifications.sqlite',
                )
                as Ok<SqliteNotificationStoreRepository, NotificationsFailure>)
            .value;
  });

  tearDown(() async {
    await log.flush();
    await outbox.close();
    directory.deleteSync(recursive: true);
  });

  test(
    'permission request delegates success and refusal to the gateway',
    () async {
      final gateway = FakeGateway();
      final permissions = NotificationPermissionsFacade(gateway: gateway);

      expect((await permissions.request() as Ok).value, isTrue);

      gateway.permissionResult = const Ok(false);
      expect((await permissions.request() as Ok).value, isFalse);
    },
  );

  test('permission request delegates gateway failures', () async {
    final gateway = FakeGateway()
      ..permissionResult = const Err(NotificationsGatewayFailure());
    final permissions = NotificationPermissionsFacade(gateway: gateway);

    expect(await permissions.request(), isA<Err>());
  });

  test('initialize does not request permission implicitly', () async {
    final gateway = FakeGateway();
    final facade = NotificationsFacade(gateway: gateway, outbox: outbox);

    expect(await facade.initialize(), isA<Ok>());
    expect(gateway.permissionRequestCount, 0);
  });

  test('each aggregate is shown once, then deleted', () async {
    final gateway = FakeGateway();
    final facade = NotificationsFacade(gateway: gateway, outbox: outbox);
    await pending(outbox, 'first');
    await pending(outbox, 'second');

    expect(await facade.deliverPending(), isA<Ok>());
    expect(await facade.deliverPending(), isA<Ok>());

    expect(gateway.shownIds, hasLength(2));
    expect(gateway.shownIds.toSet(), hasLength(2));
    expect((await outbox.claimNext() as Ok).value, isNull);
  });

  test('notifications hidden by the OS are dropped, not replayed', () async {
    final gateway = FakeGateway()..enabled = false;
    final facade = NotificationsFacade(gateway: gateway, outbox: outbox);
    await pending(outbox, 'silent');

    final result = await facade.deliverPending();

    expect(result, isA<Err>());
    expect(
      (result as Err).failure,
      isA<NotificationsPermissionDeniedFailure>(),
    );
    expect(gateway.shownIds, isEmpty);
    gateway.enabled = true;
    expect(await facade.deliverPending(), isA<Ok>());
    expect(gateway.shownIds, isEmpty);

    await pending(outbox, 'after-grant');
    expect(await facade.deliverPending(), isA<Ok>());
    expect(gateway.shownIds, hasLength(1));
    expect((await log.readLogs()).map((row) => row.split('\t')[2]), [
      'Notification permission changed allowed=false',
      'Notifications settled shown=0 denied=1',
      'Notification permission changed allowed=true',
      'Notifications settled shown=1 denied=0',
    ]);
  });

  test('the permissions facade needs no outbox', () async {
    final gateway = FakeGateway()
      ..enabled = false
      ..permissionResult = const Ok(false);
    final permissions = NotificationPermissionsFacade(gateway: gateway);

    expect((await permissions.isEnabled() as Ok).value, isFalse);
    expect((await permissions.request() as Ok).value, isFalse);
    expect(await permissions.openSystemSettings(), isA<Ok>());
    expect(gateway.permissionRequestCount, 1);
    expect(gateway.settingsOpenCount, 1);
  });

  test(
    'a failed show keeps the aggregate pending with its platform ID',
    () async {
      final gateway = FakeGateway()..fail = true;
      final facade = NotificationsFacade(gateway: gateway, outbox: outbox);
      await pending(outbox, 'failure');
      final result = await facade.deliverPending();
      expect(result, isA<Err>());
      gateway.fail = false;
      expect(await facade.deliverPending(), isA<Ok>());
      expect(gateway.shownIds, hasLength(2));
      expect(gateway.shownIds.first, gateway.shownIds.last);
    },
  );
}
