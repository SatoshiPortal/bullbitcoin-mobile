import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

class _Android extends AndroidFlutterLocalNotificationsPlugin {
  bool appEnabled = true;
  AndroidNotificationDetails? lastDetails;
  String? lastPayload;
  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async {
    lastDetails = notificationDetails;
    lastPayload = payload;
  }

  List<AndroidNotificationChannel>? channels = const [];

  @override
  Future<bool?> areNotificationsEnabled() async => appEnabled;

  @override
  Future<List<AndroidNotificationChannel>?> getNotificationChannels() async =>
      channels;
}

Matcher _ok(bool value) => isA<Ok<bool, NotificationsFailure>>().having(
  (r) => r.value,
  'value',
  value,
);

void main() {
  late _Android android;
  final gateway = FlutterLocalNotificationGateway(
    channelId: 'payments',
    channelName: 'Payments',
    channelDescription: 'Payment alerts',
    androidIconResource: 'ic_notification',
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    android = _Android();
    FlutterLocalNotificationsPlatform.instance = android;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'delivery preserves channel description, private visibility and wallet payload',
    () async {
      final destination = NotificationDestination.wallet('ab' * 32);
      expect(
        await gateway.show(
          LocalNotification(
            eventId: 'opaque-event',
            title: 'Payment confirmed',
            body: 'Incoming payments',
            destination: destination,
            createdAt: DateTime.utc(2026),
          ),
          platformId: 7,
        ),
        isA<Ok>(),
      );
      expect(android.lastDetails?.channelDescription, 'Payment alerts');
      expect(android.lastDetails?.visibility, NotificationVisibility.private);
      final payload = android.lastPayload;
      expect(payload, isNotNull);
      if (payload != null) {
        expect(
          (NotificationsFacade.decodeDestination(payload) as Ok).value,
          destination,
        );
      }
    },
  );

  test('a blocked payment channel reports notifications as hidden', () async {
    android.channels = const [
      AndroidNotificationChannel(
        'payments',
        'Payments',
        importance: Importance.none,
      ),
    ];

    expect(await gateway.isEnabled(), _ok(false));
  });

  test(
    'an allowed app with no channel yet reports notifications shown',
    () async {
      expect(await gateway.isEnabled(), _ok(true));
    },
  );

  test('another blocked channel does not hide payments', () async {
    android.channels = const [
      AndroidNotificationChannel('other', 'Other', importance: Importance.none),
      AndroidNotificationChannel('payments', 'Payments'),
    ];

    expect(await gateway.isEnabled(), _ok(true));
  });

  test('a disabled app reports notifications as hidden', () async {
    android.appEnabled = false;

    expect(await gateway.isEnabled(), _ok(false));
  });
}
