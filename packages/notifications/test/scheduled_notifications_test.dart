import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:timezone/timezone.dart' as tz;

class Android extends AndroidFlutterLocalNotificationsPlugin {
  bool allowed = true;
  bool refuseCancel = false;
  final effects = <String>[];
  final scheduled =
      <
        ({
          int id,
          DateTime date,
          AndroidScheduleMode mode,
          AndroidNotificationDetails? details,
          String? payload,
        })
      >[];
  final shown = <int>[];
  final cancelled = <int>[];
  @override
  Future<bool?> areNotificationsEnabled() async => allowed;
  @override
  Future<List<AndroidNotificationChannel>?> getNotificationChannels() async =>
      [];
  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
    AndroidNotificationDetails? notificationDetails,
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exact,
  }) async {
    effects.add('schedule:$id');
    scheduled.add((
      id: id,
      date: scheduledDate,
      mode: scheduleMode,
      details: notificationDetails,
      payload: payload,
    ));
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async {
    effects.add('show:$id');
    shown.add(id);
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    effects.add('cancel:$id');
    if (refuseCancel) throw Exception('injected cancel failure');
    cancelled.add(id);
  }
}

void main() {
  late Android android;
  final gateway = scheduledNotifications(
    channelId: 'ark-expiry',
    channelName: 'Ark',
  );
  final notification = LocalNotification(
    eventId: 'ark-expiry',
    title: 'Renew',
    body: 'Open wallet',
    createdAt: DateTime.utc(2026),
  );
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    android = Android();
    FlutterLocalNotificationsPlatform.instance = android;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test('future UTC reminder uses idle-compatible inexact high importance and no payload', () async {
    final at = DateTime.now().toUtc().add(const Duration(days: 2));
    expect(
      await gateway.schedule(notification, platformId: -1, at: at),
      isA<Ok>(),
    );
    final scheduled = android.scheduled.single;
    expect(scheduled.id, -1);
    expect(scheduled.date.toUtc(), at);
    expect(scheduled.mode, AndroidScheduleMode.inexactAllowWhileIdle);
    expect(scheduled.details?.importance, Importance.high);
    expect(scheduled.payload, isNull);
  });
  test('inside expiry margin shows immediately rather than scheduling a past alarm', () async {
    expect(
      await gateway.schedule(
        notification,
        platformId: -1,
        at: DateTime.utc(2020),
      ),
      isA<Ok>(),
    );
    expect(android.shown, [-1]);
    expect(android.scheduled, isEmpty);
  });
  test(
    'permission denial is typed and does not remove existing alarm',
    () async {
      android.allowed = false;
      expect(
        await gateway.schedule(
          notification,
          platformId: -1,
          at: DateTime.utc(2030),
        ),
        isA<Err<void, NotificationsFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<NotificationsPermissionDeniedFailure>(),
        ),
      );
      expect(android.scheduled, isEmpty);
      expect(android.cancelled, isEmpty);
    },
  );
  test('cancellation keeps stable account id', () async {
    expect(await gateway.cancelScheduled(-7), isA<Ok>());
    expect(android.cancelled, [-7]);
  });
  test('future alarm is removed before displaying immediate urgency for the same id', () async {
    expect(
      await gateway.schedule(
        notification,
        platformId: -9,
        at: DateTime.now().add(const Duration(days: 2)),
      ),
      isA<Ok>(),
    );
    expect(
      await gateway.schedule(
        notification,
        platformId: -9,
        at: DateTime.utc(2020),
      ),
      isA<Ok>(),
    );
    expect(android.effects, ['schedule:-9', 'cancel:-9', 'show:-9']);
  });
  test(
    'uncertain pending alarm cancellation refuses immediate replacement',
    () async {
      android.refuseCancel = true;
      expect(
        await gateway.schedule(
          notification,
          platformId: -9,
          at: DateTime.utc(2020),
        ),
        isA<Err>(),
      );
      expect(android.shown, isEmpty);
    },
  );
}
