import 'dart:ui';

import 'package:bull_ark/ark_debug_notification.dart';
import 'package:bull_ark/ark_notification_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

class RecordingGateway implements ScheduledNotificationPort {
  LocalNotification? notification;
  int? id;
  DateTime? at;
  bool fail = false;

  @override
  Future<Result<void, NotificationsFailure>> schedule(
    LocalNotification notification, {
    required int platformId,
    required DateTime at,
    bool cancelExisting = true,
  }) async {
    this.notification = notification;
    id = platformId;
    this.at = at;
    return fail ? const Err(NotificationsGatewayFailure()) : const Ok(null);
  }

  @override
  Future<Result<void, NotificationsFailure>> cancelScheduled(int platformId) =>
      throw StateError('The test must not cancel reminders');
}

void main() {
  test(
    'uses the production copy, reserved ID and a one minute delay',
    () async {
      final gateway = RecordingGateway();
      final now = DateTime.utc(2026, 11, 17);
      final result = await scheduleArkDebugNotification(
        gateway: gateway,
        locale: const Locale('fr'),
        now: now,
      );
      expect(result, isA<Ok<void, NotificationsFailure>>());
      expect(gateway.id, 0);
      expect(gateway.at, now.add(const Duration(seconds: 60)));
      expect(
        gateway.notification?.title,
        arkExpiryCopy(const Locale('fr')).title,
      );
      expect(
        gateway.notification?.body,
        arkExpiryCopy(const Locale('fr')).body,
      );
    },
  );

  test('propagates gateway failure', () async {
    final gateway = RecordingGateway()..fail = true;
    final result = await scheduleArkDebugNotification(
      gateway: gateway,
      locale: const Locale('en'),
      now: DateTime.utc(2026),
    );
    expect(result, isA<Err<void, NotificationsFailure>>());
  });
}
